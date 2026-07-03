module NowPlaying
  extend ActiveSupport::Concern

  private

  def mark_now_playing(level)
    Current.user.update!(now_playing_level: level.number)
    Game::PlaylistBroadcaster.call(Current.user)
  end

  def clear_permanent_toasts
    Turbo::StreamsChannel.broadcast_update_to(Current.user, :toasts, target: Game::Toasts::PERMANENT_CONTAINER, html: "")
  end
end
