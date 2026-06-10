# Colliding with the enemy locks the player out until they re-verify TOTP. The
# WASM game reports the collision and polls for the unlock; the page shows and
# clears the challenge toast over Turbo Streams.
class Games::TotpController < ApplicationController
  # Collision is posted from WASM, which can't send a CSRF token — safe to skip
  # since it's same-origin, session-gated, and only sets a flag + broadcasts.
  # (unlock keeps CSRF; its Turbo form carries the token from csrf_meta_tags.)
  skip_forgery_protection only: :collision

  # Polled by the frozen game; it resumes movement once this returns locked: false.
  def status
    render json: { locked: session[:game_totp_required].present? }
  end

  # Lock the player and broadcast the challenge toast to their own page (scoped
  # to Current.user, picked up by the turbo_stream_from on /play).
  def collision
    session[:game_totp_required] = true
    Turbo::StreamsChannel.broadcast_replace_to(
      Current.user, :toasts,
      target: toast_id,
      partial: "games/totp_challenge",
      locals: { user: Current.user }
    )
    head :no_content
  end

  # A correct code clears the lock; anything else re-renders the toast with an error.
  def unlock
    if session[:game_totp_required] && Current.user.verify_totp(params[:code])
      session.delete(:game_totp_required)
      # Remove the toast outright — the enemy's gone for good, so no later
      # collision needs the target back (a reload re-renders the slot anyway).
      render turbo_stream: turbo_stream.remove(toast_id)
    else
      render turbo_stream: turbo_stream.replace(
        toast_id,
        partial: "games/totp_challenge",
        locals: { user: Current.user, error: "Invalid code. Try again." }
      )
    end
  end

  private

  def toast_id = helpers.totp_challenge_toast_id(Current.user)
end
