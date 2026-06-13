class Games::PasskeyChallengeController < ApplicationController
  include WebauthnCeremony

  # WASM can't send a CSRF token.
  skip_forgery_protection only: :start

  def status
    render json: { locked: session[:game_passkey_required].present? }
  end

  def start
    session[:game_passkey_required] = true
    Turbo::StreamsChannel.broadcast_append_to(
      Current.user, :toasts,
      target: "toasts",
      partial: "games/passkey_challenge",
      locals: { user: Current.user }
    )
    head :no_content
  end

  # Re-auth (step-up): the player is already signed in, so scope the allow list to
  # their own registered passkeys.
  def options
    get_options = WebAuthn::Credential.options_for_get(
      allow: Current.user.webauthn_credentials.pluck(:external_id),
      user_verification: "required"
    )
    session[:game_passkey_challenge] = get_options.challenge
    render json: get_options
  end

  # A verified assertion clears the lock and broadcasts the toast removal; anything
  # else surfaces an error. Mirrors webauthn/challenges#create, for Current.user.
  def complete
    raise WebAuthn::Error unless session[:game_passkey_required]

    webauthn_credential = WebAuthn::Credential.from_get(credential_param)
    stored = Current.user.webauthn_credentials.find_by(external_id: webauthn_credential.id)
    raise WebAuthn::Error unless stored

    webauthn_credential.verify(
      session.delete(:game_passkey_challenge),
      public_key: stored.public_key,
      sign_count: stored.sign_count
    )

    stored.update!(sign_count: webauthn_credential.sign_count, last_used_at: Time.current)
    session.delete(:game_passkey_required)
    Turbo::StreamsChannel.broadcast_remove_to(Current.user, :toasts, target: toast_id)
    Achievement::Awarder.call(Current.user, :passkey_survivor)
    render json: { ok: true }
  rescue WebAuthn::Error => e
    Rails.logger.warn("Game passkey re-auth failed: #{e.class} - #{e.message}")
    render json: { error: "That passkey didn't work. Please try again." },
           status: :unprocessable_entity
  end

  private

  def toast_id = helpers.passkey_challenge_toast_id(Current.user)
end
