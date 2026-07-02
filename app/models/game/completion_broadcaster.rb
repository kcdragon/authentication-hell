# Sends the /game page to the certificate once the player beats the final level.
# Appends a tiny element to the toast stream the page already subscribes to; its
# Stimulus `redirect` controller navigates the window on connect.
class Game::CompletionBroadcaster
  def self.call(user)
    new(user).call
  end

  def initialize(user)
    @user = user
  end

  def call
    Turbo::StreamsChannel.broadcast_append_to(
      @user, :toasts,
      target: "toasts",
      partial: "games/certificate_redirect"
    )
  end
end
