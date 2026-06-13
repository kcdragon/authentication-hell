class Webauthn::AuthenticationsController < ApplicationController
  include WebauthnCeremony

  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :create,
    with: -> { render json: { error: "Try again later." }, status: :too_many_requests }

  # Usernameless login: an empty allow list lets the platform offer any discoverable
  # passkey for this site; the assertion's user handle tells us who signed in.
  def options
    get_options = WebAuthn::Credential.options_for_get(user_verification: "required")
    session[:webauthn_authentication_challenge] = get_options.challenge
    render json: get_options
  end

  def create
    webauthn_credential = WebAuthn::Credential.from_get(credential_param)
    stored = WebauthnCredential.find_by(external_id: webauthn_credential.id)

    raise WebAuthn::Error unless stored
    # The credential id is globally unique, so it already identifies the account; when
    # the authenticator also returns a user handle, it must agree (defense in depth).
    raise WebAuthn::Error if webauthn_credential.user_handle.present? && webauthn_credential.user_handle != stored.user.webauthn_id
    raise WebAuthn::Error unless stored.user.confirmed?

    webauthn_credential.verify(
      session.delete(:webauthn_authentication_challenge),
      public_key: stored.public_key,
      sign_count: stored.sign_count
    )

    stored.update!(sign_count: webauthn_credential.sign_count, last_used_at: Time.current)
    start_new_session_for stored.user
    render json: { redirect: after_authentication_url }
  rescue WebAuthn::Error => e
    Rails.logger.warn("Passkey authentication failed: #{e.class} - #{e.message}")
    render json: { error: "That passkey didn't work. Please try again." }, status: :unprocessable_entity
  end
end
