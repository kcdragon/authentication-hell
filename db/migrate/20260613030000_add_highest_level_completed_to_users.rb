class AddHighestLevelCompletedToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :highest_level_completed, :integer
  end
end
