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
      "enemies" => [ { "kind" => "totp", "x" => 1400 } ]
    }
  end
end
