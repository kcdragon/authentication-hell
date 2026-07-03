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
