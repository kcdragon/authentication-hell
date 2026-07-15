require "test_helper"

class LeaderboardControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:one) }

  test "requires authentication" do
    get leaderboard_path
    assert_redirected_to new_session_path
  end

  test "index renders" do
    sign_in_as(@user)
    get leaderboard_path
    assert_response :success
    assert_select "h1", text: "Leaderboard"
  end

  test "index renders when sorted by achievements" do
    sign_in_as(@user)
    get leaderboard_path(sort: "achievements")
    assert_response :success
  end

  test "the auths tab shows a count per auth method" do
    2.times { GameStat.record_reauth_totp(@user) }
    GameStat.record_reauth_passkey(@user)
    sign_in_as(@user)

    get leaderboard_path(tab: "auths")

    assert_response :success
    assert_select "[data-stat=reauth_totp]", text: "2"
    assert_select "[data-stat=reauth_passkey]", text: "1"
    assert_select "[data-stat=reauth_password]", text: "0"
  end

  test "the defeats tab shows a count per enemy kind" do
    GameStat.record_defeat_buffering(@user)
    2.times { GameStat.record_defeat_password(@user) }
    sign_in_as(@user)

    get leaderboard_path(tab: "defeats")

    assert_response :success
    assert_select "[data-stat=defeat_buffering]", text: "1"
    assert_select "[data-stat=defeat_password]", text: "2"
  end

  test "the times tab shows a formatted best time per level" do
    LevelCompletion.record(@user, 1, 42_000)
    sign_in_as(@user)

    get leaderboard_path(tab: "times")

    assert_response :success
    assert_select "[data-stat=best_time_level_1]", text: "0:42.0"
  end

  test "the times tab ranks faster clears first" do
    other = users(:two)
    LevelCompletion.record(@user, 1, 64_500)
    LevelCompletion.record(other, 1, 42_000)
    sign_in_as(@user)

    get leaderboard_path(tab: "times")

    assert_response :success
    times = css_select("[data-level-board=1] [data-stat=best_time_level_1]").map(&:text)
    assert_equal [ "0:42.0", "1:04.5" ], times
  end

  test "the times tab shows an empty state for a level with no clears" do
    sign_in_as(@user)

    get leaderboard_path(tab: "times")

    assert_response :success
    assert_select "[data-level-board=1]", text: /No clears yet/
  end

  test "index falls back to the achievements tab for an unknown one" do
    sign_in_as(@user)
    get leaderboard_path(tab: "bogus")
    assert_response :success
    assert_select "[data-stat]", count: 0
  end

  test "index falls back to a valid sort for an unknown one" do
    sign_in_as(@user)
    get leaderboard_path(sort: "bogus")
    assert_response :success
  end
end
