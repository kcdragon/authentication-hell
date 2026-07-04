class Games::LevelApiKeyChallengeController < ApplicationController
  skip_forgery_protection only: %i[ start ]

  def status
    render json: { opened: Current.session.temporary_api_key_challenge&.opened? || false }
  end

  def start
    Current.session.temporary_api_key_challenge&.destroy
    broadcast_toast
    head :no_content
  end

  def create
    challenge = Current.session.temporary_api_key_challenge ||
                Current.session.create_temporary_api_key_challenge!
    render turbo_stream: turbo_stream.replace(
      toast_id, partial: "games/level_api_key_challenge",
      locals: { user: Current.user, challenge: challenge, base_url: request.base_url }
    )
  end

  private

  def broadcast_toast
    Turbo::StreamsChannel.broadcast_append_to(
      Current.user, :toasts, target: Game::Toasts::PERMANENT_CONTAINER,
      partial: "games/level_api_key_challenge",
      locals: { user: Current.user, challenge: nil }
    )
  end

  def toast_id = helpers.level_api_key_challenge_toast_id(Current.user)
end
