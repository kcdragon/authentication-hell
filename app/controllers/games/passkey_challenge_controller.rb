class Games::PasskeyChallengeController < ApplicationController
  # WASM can't send a CSRF token; safe since start is same-origin, session-gated,
  # and only sets a flag + broadcasts. (complete keeps CSRF via the Turbo form.)
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

  # Placeholder: clears the lock with no verification yet. Gate on a verified
  # WebAuthn assertion once passkeys land.
  def complete
    session.delete(:game_passkey_required)
    render turbo_stream: turbo_stream.remove(toast_id)
  end

  private

  def toast_id = helpers.passkey_challenge_toast_id(Current.user)
end
