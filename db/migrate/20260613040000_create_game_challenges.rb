class CreateGameChallenges < ActiveRecord::Migration[8.1]
  def change
    create_table :game_challenges do |t|
      t.references :session, null: false, foreign_key: true
      t.string :kind, null: false

      t.timestamps
    end

    # One pending challenge per kind per session; concurrent kinds coexist as
    # separate rows. The unique index makes start idempotent.
    add_index :game_challenges, [ :session_id, :kind ], unique: true
  end
end
