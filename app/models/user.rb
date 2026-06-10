class User < ApplicationRecord
  TOTP_ISSUER = "Authentication Hell".freeze
  RECOVERY_CODE_COUNT = 10

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :recovery_codes, dependent: :destroy

  encrypts :totp_secret

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  normalizes :username, with: ->(u) { u.strip }

  validates :email_address, presence: true, uniqueness: true
  validates :username,
    presence: true,
    length: { in: 3..20 },
    format: { with: /\A[a-zA-Z0-9_]+\z/, message: "may only contain letters, numbers, and underscores" },
    uniqueness: { case_sensitive: false }

  generates_token_for :email_confirmation, expires_in: 1.day do
    email_address
  end

  def confirmed?
    confirmed_at.present?
  end

  def confirm!
    update_column(:confirmed_at, Time.current) unless confirmed?
  end

  def totp_enabled?
    totp_enabled
  end

  def totp
    ROTP::TOTP.new(totp_secret, issuer: TOTP_ISSUER) if totp_secret.present?
  end

  def provisioning_uri
    totp&.provisioning_uri(email_address)
  end

  # Verifies a TOTP code, allowing one step of clock drift behind. Persists the
  # matched timestamp so a code (or any earlier one) cannot be replayed.
  def verify_totp(code)
    return false unless totp && code.present?

    timestamp = totp.verify(code.to_s.strip, drift_behind: 15, after: last_totp_at)
    return false unless timestamp

    update!(last_totp_at: timestamp)
    true
  end

  def enable_totp!(secret)
    update!(totp_secret: secret, totp_enabled: true)
  end

  def disable_totp!
    transaction do
      update!(totp_secret: nil, totp_enabled: false, last_totp_at: nil)
      recovery_codes.delete_all
    end
  end

  # Replaces any existing recovery codes with a fresh set, storing only bcrypt
  # digests. Returns the plaintext codes for one-time display to the user.
  def generate_recovery_codes!(count = RECOVERY_CODE_COUNT)
    codes = Array.new(count) { SecureRandom.alphanumeric(10).downcase }
    transaction do
      recovery_codes.delete_all
      codes.each { |code| recovery_codes.create!(code_digest: BCrypt::Password.create(code)) }
    end
    codes
  end

  # Consumes a matching unused recovery code, marking it used. Returns true on success.
  def consume_recovery_code(code)
    return false if code.blank?

    candidate = code.to_s.strip
    recovery_code = recovery_codes.unused.find do |rc|
      BCrypt::Password.new(rc.code_digest) == candidate
    end
    return false unless recovery_code

    recovery_code.update!(used_at: Time.current)
    true
  end

  def recovery_codes_remaining
    recovery_codes.unused.count
  end
end
