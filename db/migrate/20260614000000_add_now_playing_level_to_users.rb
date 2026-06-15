class AddNowPlayingLevelToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :now_playing_level, :integer
  end
end
