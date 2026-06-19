module NowPlaying
  extend ActiveSupport::Concern

  private

  def mark_now_playing(level)
    Current.user.update!(now_playing_level: level.number)
    Game::PlaylistBroadcaster.call(Current.user)
  end
end
