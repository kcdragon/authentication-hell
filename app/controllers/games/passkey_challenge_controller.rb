class Games::PasskeyChallengeController < ApplicationController
  include WebauthnCeremony

  # WASM can't send a CSRF token.
  skip_forgery_protection only: :start

  def status
    render json: { locked: Current.session.game_challenges.exists?(kind: "passkey") }
  end

  def start
    Current.session.game_challenges.find_or_create_by!(kind: "passkey")
    Turbo::StreamsChannel.broadcast_append_to(
      Current.user, :toasts,
      target: Game::Toasts::PERMANENT_CONTAINER,
      partial: "games/passkey_challenge",
      locals: { user: Current.user }
    )
    head :no_content
  end

  def options
    get_options = WebAuthn::Credential.options_for_get(
      allow: Current.user.webauthn_credentials.pluck(:external_id),
      user_verification: "required"
    )
    session[:game_passkey_challenge] = get_options.challenge
    render json: get_options
  end

  def complete
    raise WebAuthn::Error unless Current.session.game_challenges.exists?(kind: "passkey")

    webauthn_credential = WebAuthn::Credential.from_get(credential_param)
    stored = Current.user.webauthn_credentials.find_by(external_id: webauthn_credential.id)
    raise WebAuthn::Error unless stored

    webauthn_credential.verify(
      session.delete(:game_passkey_challenge),
      public_key: stored.public_key,
      sign_count: stored.sign_count
    )

    stored.update!(sign_count: webauthn_credential.sign_count, last_used_at: Time.current)
    Current.session.game_challenges.where(kind: "passkey").delete_all
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
