require "webauthn/fake_client"

module SessionTestHelper
  # The origin the fake authenticator signs over; must match config/initializers/webauthn.rb.
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

  # Enables TOTP 2FA for a user (encrypted secret + recovery codes) and returns the
  # raw secret so tests can compute valid codes with ROTP::TOTP.new(secret).now.
  def enable_2fa_for(user)
    secret = ROTP::Base32.random
    user.enable_totp!(secret)
    user.generate_recovery_codes!
    secret
  end

  # Registers a passkey for a user with a fresh fake authenticator and returns the
  # WebAuthn::FakeClient so tests can later produce assertions from the same device.
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

  # Runs a registration ceremony over HTTP against the credentials endpoints (works for
  # both a signed-in user and a passwordless signup in progress). Returns the response.
  def register_passkey_over_http(nickname: "Laptop", client: WebAuthn::FakeClient.new(WEBAUTHN_TEST_ORIGIN))
    post options_webauthn_credentials_path, params: { nickname: nickname }, as: :json
    created = client.create(challenge: response.parsed_body["challenge"], user_verified: true)
    post webauthn_credentials_path, params: { credential: created, nickname: nickname }, as: :json
    response
  end

  # Runs an assertion ceremony over HTTP: fetch options from options_url, sign them with
  # the fake client, and POST the assertion to callback_url. Returns the final response.
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
