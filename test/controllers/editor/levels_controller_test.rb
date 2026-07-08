require "test_helper"

class Editor::LevelsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @root = Pathname.new(Dir.mktmpdir)
    @draft_root = Pathname.new(Dir.mktmpdir)
    Editor::LevelFile.root = @root
    Editor::LevelFile.draft_root = @draft_root
  end

  teardown do
    Editor::LevelFile.root = Rails.root.join("game/mygame/data/levels")
    Editor::LevelFile.draft_root = Rails.root.join("level_drafts")
    FileUtils.remove_entry(@root)
    FileUtils.remove_entry(@draft_root)
  end

  test "every action returns 404 outside development" do
    sign_in_as(@user)

    get editor_levels_url
    assert_response :not_found

    get editor_level_url("level-5")
    assert_response :not_found

    post editor_levels_url, params: valid_data.to_json, headers: json_headers
    assert_response :not_found

    post promote_editor_level_url("level-5")
    assert_response :not_found
    assert_empty Dir.children(@root)
    assert_empty Dir.children(@draft_root)
  end

  test "requires authentication" do
    in_environment("development") do
      get editor_levels_url
      assert_redirected_to new_session_path
    end
  end

  test "index lists saved levels with draft status and the next slug" do
    sign_in_as(@user)
    Editor::LevelFile.new(valid_data).write

    in_environment("development") { get editor_levels_url }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ { "slug" => "level-5", "title" => "Buffer Overflow", "draft" => true } ],
                 body["levels"]
    assert_equal "level-6", body["next_slug"]
  end

  test "show returns the stored JSON or 404" do
    sign_in_as(@user)
    Editor::LevelFile.new(valid_data).write

    in_environment("development") do
      get editor_level_url("level-5")
      assert_response :success
      assert_equal "Buffer Overflow", JSON.parse(response.body)["title"]

      get editor_level_url("level-6")
      assert_response :not_found
    end
  end

  test "create writes a new level into the drafts directory" do
    sign_in_as(@user)

    in_environment("development") do
      post editor_levels_url, params: valid_data.to_json, headers: json_headers
    end

    assert_response :success
    assert_equal({ "ok" => true, "slug" => "level-5", "draft" => true }, JSON.parse(response.body))
    assert File.file?(@draft_root.join("level-5.json"))
    assert_empty Dir.children(@root)
  end

  test "create awards the level creator achievement and toasts the first time" do
    sign_in_as(@user)

    assert_difference -> { @user.earned_achievements.count }, 1 do
      in_environment("development") do
        streams = capture_turbo_stream_broadcasts([ @user, :toasts ]) do
          post editor_levels_url, params: valid_data.to_json, headers: json_headers
        end
        assert(streams.any? { |s| s.to_html.include?("Achievement unlocked") })
      end
    end

    assert_response :success
    assert @user.earned?(:level_creator)
  end

  test "create does not re-award the level creator achievement on a later save" do
    sign_in_as(@user)
    @user.grant_achievement(:level_creator)

    assert_no_difference -> { @user.earned_achievements.count } do
      in_environment("development") do
        post editor_levels_url, params: valid_data.merge("slug" => "level-6").to_json,
                                headers: json_headers
      end
    end

    assert_response :success
  end

  test "create permits and persists an authored start_y" do
    sign_in_as(@user)

    in_environment("development") do
      post editor_levels_url, params: valid_data.merge("start_y" => 250).to_json,
                              headers: json_headers
    end

    assert_response :success
    assert_equal 250, JSON.parse(File.read(@draft_root.join("level-5.json")))["start_y"]
  end

  test "promote moves a draft into the game and refuses a second promotion" do
    sign_in_as(@user)
    Editor::LevelFile.new(valid_data).write

    in_environment("development") do
      post promote_editor_level_url("level-5")
      assert_response :success
      assert_equal({ "ok" => true, "slug" => "level-5" }, JSON.parse(response.body))
      assert File.file?(@root.join("level-5.json"))
      assert_empty Dir.children(@draft_root)

      post promote_editor_level_url("level-5")
      assert_response :unprocessable_entity

      post promote_editor_level_url("level-99")
      assert_response :not_found
    end
  end

  test "saving a promoted level updates the published file" do
    sign_in_as(@user)
    Editor::LevelFile.new(valid_data).write
    Editor::LevelFile.find("level-5").promote!

    in_environment("development") do
      post editor_levels_url, params: valid_data.merge("title" => "Revised").to_json,
                              headers: json_headers
    end

    assert_response :success
    assert_equal false, JSON.parse(response.body)["draft"]
    assert_equal "Revised", JSON.parse(File.read(@root.join("level-5.json")))["title"]
    assert_empty Dir.children(@draft_root)
  end

  test "create rejects invalid level data with errors" do
    sign_in_as(@user)

    in_environment("development") do
      post editor_levels_url, params: valid_data.merge("accent" => "mauve").to_json,
                              headers: json_headers
    end

    assert_response :unprocessable_entity
    assert_includes JSON.parse(response.body)["errors"], "accent is unknown"
    assert_empty Dir.children(@root)
    assert_empty Dir.children(@draft_root)
  end

  test "create rejects a body that is not JSON" do
    sign_in_as(@user)

    in_environment("development") do
      post editor_levels_url, params: "not json", headers: json_headers
    end

    assert_response :bad_request
    assert_empty Dir.children(@root)
    assert_empty Dir.children(@draft_root)
  end

  test "create never writes outside the levels directory" do
    sign_in_as(@user)

    in_environment("development") do
      post editor_levels_url, params: valid_data.merge("slug" => "../evil").to_json,
                              headers: json_headers
    end

    assert_response :unprocessable_entity
    assert_not File.exist?(@root.parent.join("evil.json"))
  end

  private

  def json_headers = { "Content-Type" => "application/json" }

  def in_environment(name)
    original = Rails.env
    Rails.env = name
    yield
  ensure
    Rails.env = original
  end

  def valid_data
    {
      "format" => 1,
      "slug" => "level-5",
      "title" => "Buffer Overflow",
      "accent" => "purple",
      "world_w" => 6400,
      "start_x" => 200,
      "time_limit" => 120,
      "certificate_x" => 6120,
      "platforms" => [ { "x" => 360, "y" => 220, "w" => 180 } ],
      "holes" => [ { "x" => 900, "w" => 150 } ],
      "enemies" => [ { "kind" => "totp", "x" => 1400, "y" => 100 } ]
    }
  end
end
