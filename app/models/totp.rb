class Totp
  ISSUER = "Authentication Hell".freeze
  DRIFT_BEHIND = 15

  def self.generate_random_secret = ROTP::Base32.random

  attr_reader :secret

  def initialize(secret)
    @secret = secret
  end

  def provisioning_uri(label) = rotp.provisioning_uri(label)

  def now = rotp.now

  # Returns the matched timestamp (for replay tracking) or nil.
  def verify(code, after: nil)
    return nil if code.blank?

    rotp.verify(code.to_s.strip, drift_behind: DRIFT_BEHIND, after: after)
  end

  private

  def rotp = ROTP::TOTP.new(secret, issuer: ISSUER)
end
