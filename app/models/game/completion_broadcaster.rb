class Game::CompletionBroadcaster
  def self.call(user)
    new(user).call
  end

  def self.clear(user)
    Turbo::StreamsChannel.broadcast_remove_to(user, :toasts, target: ApplicationController.helpers.certificate_toast_id)
  end

  def initialize(user)
    @user = user
  end

  def call
    Turbo::StreamsChannel.broadcast_append_to(
      @user, :toasts,
      target: "toasts",
      partial: "games/certificate_toast"
    )
  end
end
