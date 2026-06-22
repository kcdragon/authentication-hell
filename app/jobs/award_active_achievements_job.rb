class AwardActiveAchievementsJob < ApplicationJob
  queue_as :default

  def perform(user, time)
    Achievement.active_at(time).each do |achievement|
      Achievement::Awarder.call(user, achievement.key)
    end
  end
end
