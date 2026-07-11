class GameStat < ApplicationRecord
  REAUTH_KINDS = %w[ totp password passkey ].freeze
  DEFEAT_KINDS = %w[ totp password passkey buffering ].freeze

  belongs_to :user

  validates :key, presence: true

  def self.record(user, key)
    upsert(
      { user_id: user.id, key: key.to_s, count: 1 },
      unique_by: %i[ user_id key ],
      on_duplicate: Arel.sql(%("count" = "count" + 1, updated_at = CURRENT_TIMESTAMP))
    )
  end

  def self.record_reauth_totp(user) = record(user, "reauth_totp")

  def self.record_reauth_password(user) = record(user, "reauth_password")

  def self.record_reauth_passkey(user) = record(user, "reauth_passkey")

  def self.record_defeat_totp(user) = record(user, "defeat_totp")

  def self.record_defeat_password(user) = record(user, "defeat_password")

  def self.record_defeat_passkey(user) = record(user, "defeat_passkey")

  def self.record_defeat_buffering(user) = record(user, "defeat_buffering")
end
