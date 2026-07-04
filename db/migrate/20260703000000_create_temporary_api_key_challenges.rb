class CreateTemporaryApiKeyChallenges < ActiveRecord::Migration[8.1]
  def change
    create_table :temporary_api_key_challenges do |t|
      t.references :session, null: false, foreign_key: true, index: { unique: true }
      t.string :token, index: { unique: true }
      t.datetime :opened_at

      t.timestamps
    end
  end
end
