require "test_helper"

class Games::PasskeyChallengeControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier
  include Games::PasskeyHelper

  setup { @user = users(:one) }

  test "start requires authentication" do
    post games_passkey_start_url
    assert_redirected_to new_session_path
  end

  test "start broadcasts the passkey challenge toast and locks the player" do
    sign_in_as(@user)

    streams = capture_turbo_stream_broadcasts([ @user, :toasts ]) do
      post games_passkey_start_url
    end

    assert_equal 1, streams.size
    broadcast = streams.first
    assert_equal "append", broadcast["action"]
    assert_equal "toasts", broadcast["target"]
    assert_includes broadcast.to_html, "You bumped into the passkey enemy!"

    assert_response :no_content

    get games_passkey_status_url
    assert_equal({ "locked" => true }, response.parsed_body)
  end

  test "status requires authentication" do
    get games_passkey_status_url
    assert_redirected_to new_session_path
  end

  test "status reports unlocked until a collision locks the player" do
    sign_in_as(@user)

    get games_passkey_status_url
    assert_equal({ "locked" => false }, response.parsed_body)

    post games_passkey_start_url
    get games_passkey_status_url
    assert_equal({ "locked" => true }, response.parsed_body)
  end

  test "complete requires authentication" do
    post games_passkey_complete_url
    assert_redirected_to new_session_path
  end

  # Placeholder dismiss: clears the lock with no verification yet (real WebAuthn pending).
  test "complete dismisses the toast and clears the lock" do
    sign_in_as(@user)
    post games_passkey_start_url

    post games_passkey_complete_url, as: :turbo_stream

    assert_response :success
    assert_match "turbo-stream", response.media_type
    assert_includes response.body, %(<turbo-stream action="remove" target="#{passkey_challenge_toast_id(@user)}">)
    get games_passkey_status_url
    assert_equal({ "locked" => false }, response.parsed_body)
  end
end
