class Achievement::Awarder
  def self.call(user, key)
    new(user, key).call
  end

  def initialize(user, key)
    @user = user
    @key = key
  end

  def call
    return unless @user.grant_achievement(@key)

    Turbo::StreamsChannel.broadcast_append_to(
      @user, :toasts,
      target: Game::Toasts::EPHEMERAL_CONTAINER,
      partial: "games/achievement_toast",
      locals: { achievement: Achievement.find(@key) }
    )
  end
end
