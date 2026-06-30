class CreateTemporaryTotpChallenges < ActiveRecord::Migration[8.1]
  def change
    create_table :temporary_totp_challenges do |t|
      t.references :session, null: false, foreign_key: true, index: { unique: true }
      t.string  :secret, null: false
      t.boolean :registered, null: false, default: false
      t.integer :streak, null: false, default: 0
      t.integer :last_window
      t.integer :last_at

      t.timestamps
    end
  end
end
