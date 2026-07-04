class RenumberLevelsForApiKeyLevel < ActiveRecord::Migration[8.1]
  def up
    execute "UPDATE earned_achievements SET achievement_key = 'level_4_complete' WHERE achievement_key = 'level_3_complete'"
    execute "UPDATE earned_achievements SET achievement_key = 'level_3_complete' WHERE achievement_key = 'level_2_complete'"
    execute "UPDATE users SET highest_level_completed = highest_level_completed + 1 WHERE highest_level_completed >= 2"
    execute "UPDATE users SET now_playing_level = now_playing_level + 1 WHERE now_playing_level >= 2"
  end

  def down
    execute "UPDATE users SET now_playing_level = now_playing_level - 1 WHERE now_playing_level >= 3"
    execute "UPDATE users SET highest_level_completed = highest_level_completed - 1 WHERE highest_level_completed >= 3"
    execute "UPDATE earned_achievements SET achievement_key = 'level_2_complete' WHERE achievement_key = 'level_3_complete'"
    execute "UPDATE earned_achievements SET achievement_key = 'level_3_complete' WHERE achievement_key = 'level_4_complete'"
  end
end
