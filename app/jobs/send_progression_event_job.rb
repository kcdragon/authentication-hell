class SendProgressionEventJob < ApplicationJob
  queue_as :default

  def perform(user, attributes)
    Gamestats::Client.progression_event(player_username: user.username, **attributes.symbolize_keys)
  end
end
