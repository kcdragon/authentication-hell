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

  test "me requires authentication" do
    get play_me_url
    assert_redirected_to new_session_path
  end

  test "me returns the current user's username as JSON" do
    sign_in_as(@user)

    get play_me_url
    assert_response :success
    assert_equal({ "username" => @user.username }, response.parsed_body)
  end

  test "me echoes the request Origin with credentials for the WASM worker fetch" do
    sign_in_as(@user)

    get play_me_url, headers: { "Origin" => "http://example.test" }
    assert_response :success
    assert_equal "http://example.test", response.headers["Access-Control-Allow-Origin"]
    assert_equal "true", response.headers["Access-Control-Allow-Credentials"]
  end
end
