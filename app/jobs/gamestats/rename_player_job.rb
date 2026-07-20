class Gamestats::RenamePlayerJob < ApplicationJob
  queue_as :default

  def perform(old_username, new_username)
    raise Gamestats::Client::Error, "gamestats.ai is not configured" unless Gamestats::Client.configured?

    Gamestats::Client.rename_player(old_username:, new_username:)
  end
end
