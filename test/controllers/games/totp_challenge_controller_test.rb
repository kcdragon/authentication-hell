require "test_helper"

class Games::TotpChallengeControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier
  include Games::TotpHelper

  setup { @user = users(:one) }

  test "start requires authentication" do
    post games_totp_start_url
    assert_redirected_to new_session_path
  end

  test "start broadcasts the TOTP re-auth toast and locks the player" do
    sign_in_as(@user)

    streams = capture_turbo_stream_broadcasts([ @user, :toasts ]) do
      post games_totp_start_url
    end

    assert_equal 1, streams.size
    broadcast = streams.first
    assert_equal "append", broadcast["action"]
    assert_equal "toasts", broadcast["target"]
    assert_includes broadcast.to_html, "Re-authenticate with your TOTP code"

    assert_response :no_content

    get games_totp_status_url
    assert_equal({ "locked" => true }, response.parsed_body)
  end

  test "status requires authentication" do
    get games_totp_status_url
    assert_redirected_to new_session_path
  end

  test "status reports unlocked until a collision locks the player" do
    sign_in_as(@user)

    get games_totp_status_url
    assert_equal({ "locked" => false }, response.parsed_body)

    post games_totp_start_url
    get games_totp_status_url
    assert_equal({ "locked" => true }, response.parsed_body)
  end

  test "complete requires authentication" do
    post games_totp_complete_url
    assert_redirected_to new_session_path
  end

  test "complete with a valid TOTP code clears the lock" do
    secret = enable_2fa_for(@user)
    sign_in_as(@user)
    post games_totp_start_url

    post games_totp_complete_url, params: { code: ROTP::TOTP.new(secret).now }, as: :turbo_stream

    assert_response :success
    assert_match "turbo-stream", response.media_type
    assert_includes response.body, %(<turbo-stream action="remove" target="#{totp_challenge_toast_id(@user)}">)
    assert_not_includes response.body, "Re-authenticate with your TOTP code"
    get games_totp_status_url
    assert_equal({ "locked" => false }, response.parsed_body)
  end

  test "complete with an invalid code keeps the player locked and shows an error" do
    enable_2fa_for(@user)
    sign_in_as(@user)
    post games_totp_start_url

    post games_totp_complete_url, params: { code: "000000" }, as: :turbo_stream

    assert_response :success
    assert_includes response.body, "Invalid code. Try again."
    get games_totp_status_url
    assert_equal({ "locked" => true }, response.parsed_body)
  end

  test "complete cannot clear the lock for a player without TOTP enabled" do
    sign_in_as(@user)
    post games_totp_start_url

    post games_totp_complete_url, params: { code: "000000" }, as: :turbo_stream

    assert_response :success
    get games_totp_status_url
    assert_equal({ "locked" => true }, response.parsed_body)
  end
end
