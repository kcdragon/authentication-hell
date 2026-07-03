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

  test "beating the final level awards Graduate and toasts a certificate claim link" do
    last = GameLevel.all.last
    @user.update!(highest_level_completed: last.number - 1)
    sign_in_as(@user)

    streams = nil
    assert_difference -> { @user.earned_achievements.count }, 2 do
      streams = capture_turbo_stream_broadcasts([ @user, :toasts ]) do
        post games_levels_complete_url, params: { level: last.number }
      end
    end

    assert @user.earned?(:graduate)
    assert(streams.any? { |s| s.to_html.include?("Achievement unlocked") })
    assert(streams.any? { |s| s.to_html.include?(certificate_path) && s.to_html.include?("Course Complete") },
      "expected a permanent toast linking to the certificate")
  end

  test "beating the final level enqueues certificate PDF generation" do
    last = GameLevel.all.last
    @user.update!(highest_level_completed: last.number - 1)
    sign_in_as(@user)

    assert_enqueued_with(job: GenerateCertificatePdfJob) do
      post games_levels_complete_url, params: { level: last.number }
    end
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
end
