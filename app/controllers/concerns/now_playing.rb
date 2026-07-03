module NowPlaying
  extend ActiveSupport::Concern

  private

  def mark_now_playing(level)
    Current.user.update!(now_playing_level: level.number)
    Game::PlaylistBroadcaster.call(Current.user)
  end

  def clear_completion_toast_if_beaten
    Game::CompletionBroadcaster.clear(Current.user) if Current.user.beat_game?
  end
end
