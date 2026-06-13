class CreateEarnedAchievements < ActiveRecord::Migration[8.1]
  def change
    create_table :earned_achievements do |t|
      t.references :user, null: false, foreign_key: true
      t.string :achievement_key, null: false

      t.timestamps
    end

    add_index :earned_achievements, [ :user_id, :achievement_key ], unique: true
  end
end
