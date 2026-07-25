class SendAchievementEventJob < ApplicationJob
  queue_as :default

  def perform(user, achievement_key, occurred_at)
    Gamestats::Client.achievement_event(
      player_username: user.username,
      achievement_name: achievement_key,
      occurred_at: occurred_at
    )
  end
end
