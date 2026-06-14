require "test_helper"

class Webauthn::ChallengesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:two)
    @client = enable_passkey_for(@user)
    # Complete the credential stack so passing the challenge lands in the game, not onboarding.
    enable_2fa_for(@user)
  end

  def start_pending_login
    post session_path, params: { email_address: @user.email_address, password: "password" }
    assert_redirected_to new_totp_challenge_path
  end

  test "a password user with a passkey is sent to the second-factor step" do
    start_pending_login
    assert_nil cookies[:session_id].presence
  end

  test "passing the passkey challenge completes sign-in" do
    start_pending_login

    response = assert_with_passkey(@client, options_webauthn_challenge_path, webauthn_challenge_path)

    assert_response :success
    assert_equal game_url, response.parsed_body["redirect"]
    assert cookies[:session_id].present?
  end

  test "the passkey challenge requires a pending login" do
    post options_webauthn_challenge_path, as: :json
    assert_redirected_to new_session_path
  end
end
