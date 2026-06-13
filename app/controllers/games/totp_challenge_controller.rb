class Games::TotpChallengeController < ApplicationController
  # WASM can't send a CSRF token.
  skip_forgery_protection only: :start

  def status
    render json: { locked: Current.session.game_challenges.exists?(kind: "totp") }
  end

  def start
    Current.session.game_challenges.find_or_create_by!(kind: "totp")
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
    if Current.session.game_challenges.exists?(kind: "totp") && Current.user.verify_totp(params[:code])
      Current.session.game_challenges.where(kind: "totp").delete_all
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
