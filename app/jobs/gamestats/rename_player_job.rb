class Gamestats::RenamePlayerJob < ApplicationJob
  queue_as :default

  def perform(old_username, new_username)
    Gamestats::Client.rename_player(old_username:, new_username:)
  end
end
