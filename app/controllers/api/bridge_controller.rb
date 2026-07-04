class Api::BridgeController < Api::ApplicationController
  def create
    if bearer_token.blank?
      render json: { error: "missing_token",
                     hint: "Send your key as: Authorization: Bearer ah_..." },
             status: :unauthorized
    elsif challenge.nil?
      render json: { error: "invalid_token",
                     hint: "That key doesn't open this bridge. Restart the level to mint a fresh one." },
             status: :unauthorized
    elsif challenge.opened?
      render json: { bridge: "extended", message: "The bridge is already out — go cross it!" }
    else
      challenge.open!
      broadcast_opened
      render json: { bridge: "extended",
                     message: "Authenticated. Extending the bridge — get back to the game and run!" }
    end
  end

  private

  def bearer_token = request.authorization.to_s[/\ABearer (.+)\z/, 1]

  def challenge
    @challenge ||= TemporaryApiKeyChallenge.find_by(token: bearer_token)
  end

  def broadcast_opened
    user = challenge.session.user
    Turbo::StreamsChannel.broadcast_replace_to(
      user, :toasts, target: helpers.level_api_key_challenge_toast_id(user),
      partial: "games/level_api_key_challenge",
      locals: { user: user, challenge: challenge }
    )
  end
end
