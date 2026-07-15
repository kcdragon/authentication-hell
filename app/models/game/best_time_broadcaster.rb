class Game::BestTimeBroadcaster
  def self.call(user, level, ms)
    new(user, level, ms).call
  end

  def initialize(user, level, ms)
    @user = user
    @level = level
    @ms = ms
  end

  def call
    Turbo::StreamsChannel.broadcast_append_to(
      @user, :toasts,
      target: Game::Toasts::EPHEMERAL_CONTAINER,
      partial: "games/best_time_toast",
      locals: { level: @level, ms: @ms }
    )
  end
end
