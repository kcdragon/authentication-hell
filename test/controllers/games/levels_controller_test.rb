require "test_helper"

class Games::LevelsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:one) }

  test "complete requires authentication" do
    post games_levels_complete_url, params: { level: 1 }
    assert_redirected_to new_session_path
  end

  test "complete records the reported level as the player's high-water mark" do
    sign_in_as(@user)

    post games_levels_complete_url, params: { level: 1 }

    assert_response :no_content
    assert_equal 1, @user.reload.highest_level_completed
  end

  test "completing the welcome level (level 0) records progress and awards its achievement" do
    sign_in_as(@user)

    assert_difference -> { @user.earned_achievements.count }, 1 do
      post games_levels_complete_url, params: { level: 0 }
    end

    assert_equal 0, @user.reload.highest_level_completed
    assert @user.earned?(:level_0_complete)
  end

  test "replaying an already-completed level advances now_playing without re-awarding or raising" do
    @user.update!(highest_level_completed: 0)
    @user.grant_achievement(:level_0_complete)
    sign_in_as(@user)

    assert_no_difference -> { @user.earned_achievements.count } do
      post games_levels_complete_url, params: { level: 0 }
    end

    assert_response :no_content
    assert_equal 1, @user.reload.now_playing_level
  end

  test "complete never lowers an already-higher progress mark" do
    @user.update!(highest_level_completed: 1)
    sign_in_as(@user)

    post games_levels_complete_url, params: { level: 0 }

    assert_equal 1, @user.reload.highest_level_completed
  end

  test "an unknown level records no progress and awards nothing" do
    sign_in_as(@user)

    assert_no_difference -> { @user.earned_achievements.count } do
      post games_levels_complete_url, params: { level: 999 }
    end

    assert_response :no_content
    assert_nil @user.reload.highest_level_completed
  end

  test "completing a level awards its achievement and toasts it" do
    sign_in_as(@user)

    streams = nil
    assert_difference -> { @user.earned_achievements.count }, 1 do
      streams = capture_turbo_stream_broadcasts([ @user, :toasts ]) do
        post games_levels_complete_url, params: { level: 1 }
      end
    end

    assert @user.earned?(:level_1_complete)
    assert(streams.any? { |s| s.to_html.include?("Achievement unlocked") })
  end

  test "re-completing a level does not re-award or re-toast the achievement" do
    @user.grant_achievement(:level_1_complete)
    sign_in_as(@user)

    streams = nil
    assert_no_difference -> { @user.earned_achievements.count } do
      streams = capture_turbo_stream_broadcasts([ @user, :toasts ]) do
        post games_levels_complete_url, params: { level: 1 }
      end
    end

    assert_not(streams.any? { |s| s.to_html.include?("Achievement unlocked") })
  end

  test "completing a level marks the next level as now playing" do
    sign_in_as(@user)

    streams = capture_turbo_stream_broadcasts([ @user, :playlist ]) do
      post games_levels_complete_url, params: { level: 1 }
    end

    assert_equal 2, @user.reload.now_playing_level
    assert_equal 1, streams.size
  end

  test "completing the final level records progress without a next level" do
    last = GameLevel.all.last
    @user.update!(highest_level_completed: last.number - 1)
    sign_in_as(@user)

    post games_levels_complete_url, params: { level: last.number }

    assert_response :no_content
    assert_equal last.number, @user.reload.highest_level_completed
    assert_nil @user.now_playing_level
  end

  test "beating the graduation level awards Graduate, toasts a certificate claim link, and queues the bonus" do
    graduation = GameLevel.graduation
    @user.update!(highest_level_completed: graduation.number - 1)
    sign_in_as(@user)

    streams = nil
    assert_difference -> { @user.earned_achievements.count }, 2 do
      streams = capture_turbo_stream_broadcasts([ @user, :toasts ]) do
        post games_levels_complete_url, params: { level: graduation.number }
      end
    end

    assert @user.earned?(:graduate)
    assert_equal graduation.number + 1, @user.reload.now_playing_level,
      "graduating still advances into the bonus chapter"
    assert(streams.any? { |s| s.to_html.include?("Achievement unlocked") })
    assert(streams.any? { |s| s.to_html.include?(certificate_path) && s.to_html.include?("Course Complete") },
      "expected a permanent toast linking to the certificate")
  end

  test "beating the graduation level enqueues certificate PDF generation" do
    graduation = GameLevel.graduation
    @user.update!(highest_level_completed: graduation.number - 1)
    sign_in_as(@user)

    assert_enqueued_with(job: GenerateCertificatePdfJob) do
      post games_levels_complete_url, params: { level: graduation.number }
    end
  end

  test "completing the bonus level awards its achievement without re-graduating" do
    bonus = GameLevel.all.last
    @user.update!(highest_level_completed: bonus.number - 1)
    @user.grant_achievement(:graduate)
    sign_in_as(@user)

    assert_difference -> { @user.earned_achievements.count }, 1 do
      assert_no_enqueued_jobs only: GenerateCertificatePdfJob do
        post games_levels_complete_url, params: { level: bonus.number }
      end
    end

    assert @user.earned?(bonus.achievement_key)
    assert_nil @user.reload.certificate_awarded_at, "the bonus level never certifies on its own"
  end

  test "completing a promoted editor level records progress but awards no achievement" do
    root = Pathname.new(Dir.mktmpdir)
    draft_root = Pathname.new(Dir.mktmpdir)
    Editor::LevelFile.root = root
    Editor::LevelFile.draft_root = draft_root
    Editor::LevelFile.new(promoted_level_data).write
    Editor::LevelFile.find("level-9").promote!
    user_level = GameLevel.find(5)
    @user.update!(highest_level_completed: user_level.number - 1)
    sign_in_as(@user)

    assert_no_difference -> { @user.earned_achievements.count } do
      post games_levels_complete_url, params: { level: user_level.number }
    end

    assert_response :no_content
    assert_equal user_level.number, @user.reload.highest_level_completed
  ensure
    Editor::LevelFile.root = Rails.root.join("game/mygame/data/levels")
    Editor::LevelFile.draft_root = Rails.root.join("level_drafts")
    FileUtils.remove_entry(root)
    FileUtils.remove_entry(draft_root)
  end

  test "complete records the reported time as a level completion" do
    sign_in_as(@user)

    post games_levels_complete_url, params: { level: 1, ms: 42_000 }

    assert_response :no_content
    assert_equal 42_000, @user.level_completions.find_by(level_number: 1).best_ms
  end

  test "a faster replay of an already-completed level still improves the best time" do
    @user.update!(highest_level_completed: 1)
    LevelCompletion.record(@user, 1, 42_000)
    sign_in_as(@user)

    post games_levels_complete_url, params: { level: 1, ms: 30_000 }

    assert_response :no_content
    assert_equal 30_000, @user.level_completions.find_by(level_number: 1).best_ms
  end

  test "a new best time toasts the player" do
    sign_in_as(@user)

    streams = capture_turbo_stream_broadcasts([ @user, :toasts ]) do
      post games_levels_complete_url, params: { level: 1, ms: 42_000 }
    end

    assert(streams.any? { |s| s.to_html.include?("New best time") && s.to_html.include?("0:42.0") })
  end

  test "a slower replay records no better time and does not toast" do
    @user.update!(highest_level_completed: 1)
    LevelCompletion.record(@user, 1, 30_000)
    sign_in_as(@user)

    streams = capture_turbo_stream_broadcasts([ @user, :toasts ]) do
      post games_levels_complete_url, params: { level: 1, ms: 42_000 }
    end

    assert_equal 30_000, @user.level_completions.find_by(level_number: 1).best_ms
    assert_not(streams.any? { |s| s.to_html.include?("New best time") })
  end

  test "a missing, garbage, zero, or absurd time completes the level with no recorded time" do
    sign_in_as(@user)

    [ nil, "abc", "0", (LevelCompletion::MAX_MS + 1).to_s ].each do |ms|
      post games_levels_complete_url, params: { level: 1, ms: ms }.compact
      assert_response :no_content
    end

    assert_nil @user.level_completions.find_by(level_number: 1)
    assert_equal 1, @user.reload.highest_level_completed
  end

  test "playing requires authentication" do
    post games_levels_playing_url, params: { level: 1 }
    assert_redirected_to new_session_path
  end

  test "playing records the entered level and broadcasts the playlist" do
    @user.update!(highest_level_completed: 2)
    sign_in_as(@user)

    streams = capture_turbo_stream_broadcasts([ @user, :playlist ]) do
      post games_levels_playing_url, params: { level: 0 }
    end

    assert_response :no_content
    assert_equal 0, @user.reload.now_playing_level
    assert_equal 1, streams.size
  end

  test "playing tracks the reported level even before it's been cleared" do
    sign_in_as(@user)

    post games_levels_playing_url, params: { level: 2 }

    assert_response :no_content
    assert_equal 2, @user.reload.now_playing_level
  end

  test "starting a level wipes the permanent toasts so stale challenges can't linger" do
    sign_in_as(@user)
    post games_level_totp_start_url
    assert @user.sessions.last.temporary_totp_challenge.present?,
      "expected the TOTP level challenge (its toast is permanent) to be active"

    streams = capture_turbo_stream_broadcasts([ @user, :toasts ]) do
      post games_levels_playing_url, params: { level: 0 }
    end

    assert(streams.any? { |s| s["action"] == "update" && s["target"] == Game::Toasts::PERMANENT_CONTAINER },
      "expected the permanent toasts to be wiped on level start")
  end

  test "playing ignores an unknown level" do
    sign_in_as(@user)

    post games_levels_playing_url, params: { level: 999 }

    assert_response :no_content
    assert_nil @user.reload.now_playing_level
  end

  private

  def promoted_level_data
    {
      "format" => 1, "slug" => "level-9", "title" => "Level 9", "accent" => "blue",
      "world_w" => 6400, "start_x" => 200, "time_limit" => 120, "certificate_x" => 6120,
      "platforms" => [], "holes" => [], "enemies" => []
    }
  end
end
