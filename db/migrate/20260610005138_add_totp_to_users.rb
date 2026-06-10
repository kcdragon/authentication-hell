class AddTotpToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :totp_secret, :string
    add_column :users, :totp_enabled, :boolean, default: false, null: false
    add_column :users, :last_totp_at, :integer
  end
end
