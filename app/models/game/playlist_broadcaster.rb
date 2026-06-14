# Re-renders the /game playlist rail for a user and broadcasts it over the
# per-user :playlist stream the game page subscribes to, advancing the rail
# (cleared level → "Watched", next → "Now playing") without a page reload.
class Game::PlaylistBroadcaster
  def self.call(user)
    new(user).call
  end

  def initialize(user)
    @user = user
  end

  def call
    Turbo::StreamsChannel.broadcast_replace_to(
      @user, :playlist,
      target: ApplicationController.helpers.playlist_dom_id,
      partial: "games/playlist",
      locals: { user: @user }
    )
  end
end
