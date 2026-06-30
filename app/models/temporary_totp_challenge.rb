class TemporaryTotpChallenge < ApplicationRecord
  REQUIRED_STREAK = 3
  INTERVAL = 30

  belongs_to :session
  encrypts :secret

  def totp = Totp.new(secret)

  def provisioning_uri = totp.provisioning_uri("#{Totp::ISSUER} · Rolling Codes")

  def register!(code)
    return false unless totp.verify(code)

    update!(registered: true)
    true
  end

  def submit!(code)
    return :incorrect unless registered?

    timestamp = totp.verify(code, after: last_at)
    unless timestamp
      return :replay if totp.verify(code)

      update!(streak: 0)
      return :incorrect
    end

    window = timestamp / INTERVAL
    self.streak = last_window && window == last_window + 1 ? streak + 1 : 1
    self.last_window = window
    self.last_at = timestamp
    save!
    :accepted
  end

  def complete? = streak >= REQUIRED_STREAK

  def upcoming_codes(count = REQUIRED_STREAK)
    base = Time.now
    Array.new(count) { |i| totp.at(base + i * INTERVAL) }
  end
end
