require "test_helper"

class Games::PasswordChallengeControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier
  include Games::PasswordHelper

  setup { @user = users(:one) }

  test "start requires authentication" do
    post games_password_start_url
    assert_redirected_to new_session_path
  end

  test "start broadcasts the password re-auth toast and locks the player" do
    sign_in_as(@user)

    streams = capture_turbo_stream_broadcasts([ @user, :toasts ]) do
      post games_password_start_url
    end

    assert_equal 1, streams.size
    broadcast = streams.first
    assert_equal "append", broadcast["action"]
    assert_equal "toasts", broadcast["target"]
    assert_includes broadcast.to_html, "Re-authenticate with your password"

    assert_response :no_content

    get games_password_status_url
    assert_equal({ "locked" => true }, response.parsed_body)
  end

  test "status requires authentication" do
    get games_password_status_url
    assert_redirected_to new_session_path
  end

  test "status reports unlocked until a collision locks the player" do
    sign_in_as(@user)

    get games_password_status_url
    assert_equal({ "locked" => false }, response.parsed_body)

    post games_password_start_url
    get games_password_status_url
    assert_equal({ "locked" => true }, response.parsed_body)
  end

  test "complete requires authentication" do
    post games_password_complete_url
    assert_redirected_to new_session_path
  end

  test "complete with a valid password clears the lock" do
    sign_in_as(@user)
    post games_password_start_url

    post games_password_complete_url, params: { password: "password" }, as: :turbo_stream

    assert_response :success
    assert_match "turbo-stream", response.media_type
    assert_includes response.body, %(<turbo-stream action="remove" target="#{password_challenge_toast_id(@user)}">)
    assert_not_includes response.body, "Re-authenticate with your password"
    get games_password_status_url
    assert_equal({ "locked" => false }, response.parsed_body)
  end

  test "complete with an invalid password keeps the player locked and shows an error" do
    sign_in_as(@user)
    post games_password_start_url

    post games_password_complete_url, params: { password: "wrong" }, as: :turbo_stream

    assert_response :success
    assert_includes response.body, "Invalid password. Try again."
    get games_password_status_url
    assert_equal({ "locked" => true }, response.parsed_body)
  end

  test "complete cannot clear the lock for a passwordless player" do
    user = users(:passwordless)
    sign_in_as(user)
    post games_password_start_url

    post games_password_complete_url, params: { password: "password" }, as: :turbo_stream

    assert_response :success
    get games_password_status_url
    assert_equal({ "locked" => true }, response.parsed_body)
  end
end
