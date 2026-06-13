class Games::PasswordChallengeController < ApplicationController
  # WASM can't send a CSRF token.
  skip_forgery_protection only: :start

  def status
    render json: { locked: Current.session.game_challenges.exists?(kind: "password") }
  end

  def start
    Current.session.game_challenges.find_or_create_by!(kind: "password")
    Turbo::StreamsChannel.broadcast_append_to(
      Current.user, :toasts,
      target: "toasts",
      partial: "games/password_challenge",
      locals: { user: Current.user }
    )
    head :no_content
  end

  # A correct password clears the lock; anything else re-renders the toast with an error.
  def complete
    if Current.session.game_challenges.exists?(kind: "password") && Current.user.authenticate(params[:password])
      Current.session.game_challenges.where(kind: "password").delete_all
      Achievement::Awarder.call(Current.user, :password_survivor)
      render turbo_stream: turbo_stream.remove(toast_id)
    else
      render turbo_stream: turbo_stream.replace(
        toast_id,
        partial: "games/password_challenge",
        locals: { user: Current.user, error: "Invalid password. Try again." }
      )
    end
  end

  private

  def toast_id = helpers.password_challenge_toast_id(Current.user)
end
