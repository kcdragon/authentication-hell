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

  test "completing the tutorial (level 0) records progress and awards its achievement" do
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
end
