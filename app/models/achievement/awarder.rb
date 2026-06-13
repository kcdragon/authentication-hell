# Grants an achievement to a user and, only the first time it's earned,
# broadcasts the unlock toast over the same per-user :toasts stream the game
# page already subscribes to — out-of-band, so it composes with whatever the
# caller renders.
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
      target: "toasts",
      partial: "games/achievement_toast",
      locals: { achievement: Achievement.find(@key) }
    )
  end
end
