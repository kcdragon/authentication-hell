class Webauthn::ChallengesController < ApplicationController
  include WebauthnCeremony
  include Pending2fa

  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :create,
    with: -> { render json: { error: "Try again later." }, status: :too_many_requests }

  # Second factor after a password: we already know who's signing in, so scope the
  # allow list to their registered passkeys.
  def options
    get_options = WebAuthn::Credential.options_for_get(
      allow: @pending_user.webauthn_credentials.pluck(:external_id),
      user_verification: "required"
    )
    session[:webauthn_authentication_challenge] = get_options.challenge
    render json: get_options
  end

  def create
    webauthn_credential = WebAuthn::Credential.from_get(credential_param)
    stored = @pending_user.webauthn_credentials.find_by(external_id: webauthn_credential.id)

    raise WebAuthn::Error unless stored

    webauthn_credential.verify(
      session.delete(:webauthn_authentication_challenge),
      public_key: stored.public_key,
      sign_count: stored.sign_count
    )

    stored.update!(sign_count: webauthn_credential.sign_count, last_used_at: Time.current)
    clear_pending_2fa
    start_new_session_for @pending_user
    render json: { redirect: after_authentication_url }
  rescue WebAuthn::Error => e
    Rails.logger.warn("Passkey 2FA failed: #{e.class} - #{e.message}")
    render json: { error: "That passkey didn't work. Please try again." }, status: :unprocessable_entity
  end
end
