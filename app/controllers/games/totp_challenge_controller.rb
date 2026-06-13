class Games::TotpChallengeController < ApplicationController
  # WASM can't send a CSRF token; safe since start is same-origin, session-gated,
  # and only sets a flag + broadcasts. (complete keeps CSRF via the Turbo form.)
  skip_forgery_protection only: :start

  def status
    render json: { locked: session[:game_totp_required].present? }
  end

  def start
    session[:game_totp_required] = true
    Turbo::StreamsChannel.broadcast_append_to(
      Current.user, :toasts,
      target: "toasts",
      partial: "games/totp_challenge",
      locals: { user: Current.user }
    )
    head :no_content
  end

  # A correct code clears the lock; anything else re-renders the toast with an error.
  def complete
    if session[:game_totp_required] && Current.user.verify_totp(params[:code])
      session.delete(:game_totp_required)
      Achievement::Awarder.call(Current.user, :totp_survivor)
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
