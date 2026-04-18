# frozen_string_literal: true

require "digest"

class User < ApplicationRecord
  RECOVERY_CODE_COUNT = 10

  has_secure_password

  generates_token_for :email_verification, expires_in: 2.days do
    email
  end

  generates_token_for :password_reset, expires_in: 20.minutes do
    password_salt.last(10)
  end


  has_many :sessions, dependent: :destroy

  serialize :otp_recovery_codes, coder: JSON, type: Array

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true, format: {with: URI::MailTo::EMAIL_REGEXP}
  validates :password, allow_nil: true, length: {minimum: 8}

  normalizes :email, with: -> { _1.strip.downcase }

  before_validation if: :email_changed?, on: :update do
    self.verified = false
  end

  after_update if: :password_digest_previously_changed? do
    sessions.where.not(id: Current.session).delete_all
  end

  def totp_enabled?
    otp_enabled_at.present?
  end

  def otp_provisioning_uri
    ROTP::TOTP.new(otp_secret, issuer: "Authentication Hell").provisioning_uri(email)
  end

  def verify_otp(code, secret: otp_secret)
    return false if secret.blank? || code.blank?
    ROTP::TOTP.new(secret).verify(code.to_s.strip, drift_behind: 15).present?
  end

  def self.generate_otp_secret
    ROTP::Base32.random
  end

  def generate_recovery_codes!
    codes = Array.new(RECOVERY_CODE_COUNT) { self.class.format_recovery_code(SecureRandom.hex(5)) }
    self.otp_recovery_codes = codes.map { |code| self.class.hash_recovery_code(code) }
    codes
  end

  def consume_recovery_code!(code)
    hashed = self.class.hash_recovery_code(code.to_s.strip)
    remaining = (otp_recovery_codes || []).dup
    return false unless remaining.delete(hashed)
    update!(otp_recovery_codes: remaining)
    true
  end

  def disable_two_factor!
    update!(otp_secret: nil, otp_enabled_at: nil, otp_recovery_codes: [])
  end

  def self.hash_recovery_code(code)
    Digest::SHA256.hexdigest(code.to_s.strip.upcase)
  end

  def self.format_recovery_code(raw)
    hex = raw.to_s.upcase.rjust(10, "0")
    "#{hex[0, 4]}-#{hex[4, 4]}-#{hex[8, 2]}"
  end
end
