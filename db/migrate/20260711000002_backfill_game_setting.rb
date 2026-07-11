class BackfillGameSetting < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      INSERT INTO game_settings (heart_drop_chance, rewind_drop_chance, created_at, updated_at)
      SELECT 0.30, 0.35, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      WHERE NOT EXISTS (SELECT 1 FROM game_settings)
    SQL
  end

  def down
    execute "DELETE FROM game_settings"
  end
end
