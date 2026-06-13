module Games::AchievementHelper
  # DOM id of an achievement-unlock toast, built from one place so the partial
  # (and anything that targets the toast) stay in sync.
  def achievement_toast_id(achievement)
    "achievement_toast_#{achievement.key}"
  end
end
