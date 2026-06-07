class AddUsernameAndConfirmationToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :username, :string, null: false, default: ""
    add_column :users, :confirmed_at, :datetime
    add_index :users, "lower(username)", unique: true, name: "index_users_on_lower_username"
  end
end
