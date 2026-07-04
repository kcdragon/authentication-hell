module Games::LevelApiKeyHelper
  def level_api_key_challenge_toast_id(user)
    dom_id(user, :level_api_key_challenge)
  end
end
