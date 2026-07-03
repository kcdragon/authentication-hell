class Games::DeathsController < ApplicationController
  skip_forgery_protection only: :create

  def create
    Current.session.game_challenges.delete_all
    Turbo::StreamsChannel.broadcast_update_to(Current.user, :toasts, target: Game::Toasts::PERMANENT_CONTAINER, html: "")
    Turbo::StreamsChannel.broadcast_append_to(
      Current.user, :toasts,
      target: Game::Toasts::EPHEMERAL_CONTAINER,
      partial: "games/toast",
      locals: { toast: { id: "video_ended", message: "Video ended — press R to restart the video." } }
    )
    head :no_content
  end
end
