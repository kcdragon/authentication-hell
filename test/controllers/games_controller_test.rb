require "test_helper"

class GamesControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:one) }

  test "show requires authentication" do
    get play_url
    assert_redirected_to new_session_path
  end

  test "show renders the game page when signed in" do
    sign_in_as(@user)

    get play_url
    assert_response :success
  end

  # #me is temporarily unauthenticated and returns a hardcoded username while we
  # verify the game can fetch JSON from Rails at all.
  test "me returns a username without authentication" do
    get play_me_url
    assert_response :success
    assert_equal({ "username" => "kcdragon" }, response.parsed_body)
  end
end
