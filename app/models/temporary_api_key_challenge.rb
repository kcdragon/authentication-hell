class TemporaryApiKeyChallenge < ApplicationRecord
  TOKEN_PREFIX = "ah_"

  belongs_to :session
  encrypts :token, deterministic: true

  before_create { self.token ||= TOKEN_PREFIX + SecureRandom.base58(24) }

  def open!
    update!(opened_at: Time.current) unless opened?
  end

  def opened? = opened_at.present?

  def curl_command(base_url)
    %(curl -X POST #{base_url}/api/bridge -H "Authorization: Bearer #{token}")
  end
end
