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

  test "index falls back to a valid sort for an unknown one" do
    sign_in_as(@user)
    get leaderboard_path(sort: "bogus")
    assert_response :success
  end
end
