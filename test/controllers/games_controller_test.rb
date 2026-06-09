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

  test "collision requires authentication" do
    post play_collision_url
    assert_redirected_to new_session_path
  end

  test "collision appends a toast over Turbo Streams to the current user and returns no content" do
    sign_in_as(@user)

    streams = capture_turbo_stream_broadcasts([ @user, :toasts ]) do
      post play_collision_url
    end

    assert_equal 1, streams.size
    broadcast = streams.first
    assert_equal "append", broadcast["action"]
    assert_equal "toasts", broadcast["target"]
    assert_includes broadcast.to_html, "#{@user.username} bumped into the enemy!"

    assert_response :no_content
  end
end
