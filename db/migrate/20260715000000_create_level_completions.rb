class CreateLevelCompletions < ActiveRecord::Migration[8.1]
  def change
    create_table :level_completions do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :level_number, null: false
      t.integer :best_ms, null: false

      t.timestamps
    end

    add_index :level_completions, %i[ user_id level_number ], unique: true
  end
end
