class CreateGameSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :game_settings do |t|
      t.float :heart_drop_chance, null: false, default: 0.30
      t.float :rewind_drop_chance, null: false, default: 0.35

      t.timestamps
    end
  end
end
