class User < ApplicationRecord
  TOTP_ISSUER = "Authentication Hell".freeze
  RECOVERY_CODE_COUNT = 10

  AVATAR_CONTENT_TYPES = %w[ image/png image/jpeg image/gif image/webp ].freeze
  AVATAR_MAX_SIZE = 5.megabytes

  # The password db/seeds.rb gives the dev user; also prefilled into the game's
  # password challenge in development. Dev/seed convenience only, never used in production.
  DEV_PASSWORD = "password".freeze

  has_secure_password validations: false
  has_many :sessions, dependent: :destroy
  has_many :recovery_codes, dependent: :destroy
  has_many :webauthn_credentials, dependent: :destroy
  has_many :earned_achievements, dependent: :destroy

  has_one_attached :avatar do |attachable|
    attachable.variant :nav, resize_to_fill: [ 64, 64 ]
  end

  encrypts :totp_secret

  before_create { self.webauthn_id ||= WebAuthn.generate_user_id }

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  normalizes :username, with: ->(u) { u.strip }

  validates :email_address, presence: true, uniqueness: true
  validates :username,
    presence: true,
    length: { in: 3..20 },
    format: { with: /\A[a-zA-Z0-9_]+\z/, message: "may only contain letters, numbers, and underscores" },
    uniqueness: { case_sensitive: false }
  validates :password, confirmation: true, length: { maximum: 72 }, allow_nil: true, if: -> { password.present? }
  validate :password_or_passkey_present
  validate :acceptable_avatar

  generates_token_for :email_confirmation, expires_in: 1.day do
    email_address
  end

  # Signed, self-expiring handle for the post-password second-factor step, so the
  # session carries a token (not a raw id) and the timeout is enforced by the token.
  generates_token_for :pending_2fa, expires_in: 10.minutes

  def passwordless?
    password_digest.blank?
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

  # Whether logging in with a password should be followed by a second-factor step.
  def second_factor?
    totp_enabled? || webauthn_credentials.exists?
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

  def earned_achievement_keys
    earned_achievements.pluck(:achievement_key)
  end

  def earned?(key)
    earned_achievements.exists?(achievement_key: key.to_s)
  end

  # Records an achievement, returning it only the first time it's earned (nil if
  # the user already had it). The uniqueness validation/index makes repeats no-ops.
  def grant_achievement(key)
    record = earned_achievements.create(achievement_key: key.to_s)
    record if record.persisted?
  end

  def record_level_completed(level)
    return false if highest_level_completed && level <= highest_level_completed

    update!(highest_level_completed: level)
    true
  end

  # The level the player is currently on: the one after their furthest cleared
  # level (the first level if they've cleared none, the last level once they've
  # cleared everything).
  def current_level
    GameLevel.find((highest_level_completed || -1) + 1) || GameLevel.find(highest_level_completed)
  end

  private

  def password_or_passkey_present
    return if password_digest.present? || webauthn_credentials.any?

    errors.add(:base, "Add a password or a passkey to secure your account")
  end

  def acceptable_avatar
    return unless avatar.attached?

    errors.add(:avatar, "is too large (max 5 MB)") unless avatar.blob.byte_size <= AVATAR_MAX_SIZE
    unless AVATAR_CONTENT_TYPES.include?(avatar.blob.content_type)
      errors.add(:avatar, "must be a PNG, JPEG, GIF, or WebP image")
    end
  end
end
