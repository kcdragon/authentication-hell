module Games::AchievementHelper
  def achievement_toast_id(achievement)
    "achievement_toast_#{achievement.key}"
  end
end
