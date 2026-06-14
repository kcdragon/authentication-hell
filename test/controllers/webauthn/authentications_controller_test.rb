require "test_helper"

class Webauthn::AuthenticationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:passwordless)
    @client = enable_passkey_for(@user)
  end

  test "passwordless login with a registered passkey establishes a session" do
    response = assert_with_passkey(@client, options_webauthn_authentication_path, webauthn_authentication_path,
      user_handle: @user.webauthn_id)

    assert_response :success
    # A passkey-only account still lacks a password and TOTP, so it's nudged to finish setup.
    assert_equal onboarding_url, response.parsed_body["redirect"]
    assert cookies[:session_id].present?
  end

  test "login updates last_used_at on the credential" do
    assert_with_passkey(@client, options_webauthn_authentication_path, webauthn_authentication_path,
      user_handle: @user.webauthn_id)

    assert @user.webauthn_credentials.first.last_used_at.present?
  end

  test "an unconfirmed user cannot sign in with a passkey" do
    @user.update!(confirmed_at: nil)

    assert_with_passkey(@client, options_webauthn_authentication_path, webauthn_authentication_path,
      user_handle: @user.webauthn_id)

    assert_response :unprocessable_entity
    assert_nil cookies[:session_id].presence
  end

  test "an unknown credential is rejected" do
    # A device that registered with itself but was never stored in our database.
    stranger = WebAuthn::FakeClient.new(SessionTestHelper::WEBAUTHN_TEST_ORIGIN)
    create_opts = WebAuthn::Credential.options_for_create(
      user: { id: WebAuthn.generate_user_id, name: "x", display_name: "x" }
    )
    stranger.create(challenge: create_opts.challenge, user_verified: true)

    post options_webauthn_authentication_path, as: :json
    assertion = stranger.get(challenge: response.parsed_body["challenge"], user_verified: true)
    post webauthn_authentication_path, params: { credential: assertion }, as: :json

    assert_response :unprocessable_entity
    assert_nil cookies[:session_id].presence
  end
end
