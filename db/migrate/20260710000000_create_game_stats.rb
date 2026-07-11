class CreateGameStats < ActiveRecord::Migration[8.1]
  def change
    create_table :game_stats do |t|
      t.references :user, null: false, foreign_key: true
      t.string :key, null: false
      t.integer :count, null: false, default: 0

      t.timestamps
    end

    add_index :game_stats, [ :user_id, :key ], unique: true
  end
end
