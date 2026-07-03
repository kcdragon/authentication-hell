require "webauthn/fake_client"

module SessionTestHelper
  # Must match config/initializers/webauthn.rb; the fake authenticator signs over it.
  WEBAUTHN_TEST_ORIGIN = "http://localhost:3000"

  def sign_in_as(user)
    Current.session = user.sessions.create!

    ActionDispatch::TestRequest.create.cookie_jar.tap do |cookie_jar|
      cookie_jar.signed[:session_id] = Current.session.id
      cookies["session_id"] = cookie_jar[:session_id]
    end
  end

  def sign_out
    Current.session&.destroy!
    cookies.delete("session_id")
  end

  def enable_2fa_for(user)
    secret = ROTP::Base32.random
    user.enable_totp!(secret)
    user.generate_recovery_codes!
    secret
  end

  def enable_passkey_for(user, nickname: "Test passkey")
    user.update!(webauthn_id: WebAuthn.generate_user_id) if user.webauthn_id.blank?
    client = WebAuthn::FakeClient.new(WEBAUTHN_TEST_ORIGIN)

    options = WebAuthn::Credential.options_for_create(
      user: { id: user.webauthn_id, name: user.email_address, display_name: user.username }
    )
    created = WebAuthn::Credential.from_create(client.create(challenge: options.challenge, user_verified: true))
    user.webauthn_credentials.create!(
      external_id: created.id, public_key: created.public_key,
      sign_count: created.sign_count, nickname: nickname
    )
    client
  end

  def register_passkey_over_http(nickname: "Laptop", client: WebAuthn::FakeClient.new(WEBAUTHN_TEST_ORIGIN))
    post options_webauthn_credentials_path, params: { nickname: nickname }, as: :json
    created = client.create(challenge: response.parsed_body["challenge"], user_verified: true)
    post webauthn_credentials_path, params: { credential: created, nickname: nickname }, as: :json
    response
  end

  # Pass user_handle: user.webauthn_id to simulate a discoverable (usernameless) credential.
  def assert_with_passkey(client, options_url, callback_url, user_handle: nil)
    post options_url, as: :json
    challenge = response.parsed_body["challenge"]

    raw_handle = user_handle && WebAuthn.configuration.encoder.decode(user_handle)
    assertion = client.get(challenge: challenge, user_verified: true, user_handle: raw_handle)

    post callback_url, params: { credential: assertion }, as: :json
    response
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) do
  include SessionTestHelper
end
