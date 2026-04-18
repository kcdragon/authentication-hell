# frozen_string_literal: true

# Configure Active Record encryption keys from environment variables.
#
# Production must supply all three; dev/test fall back to well-known,
# non-secret defaults so the suite runs without bootstrap.
module ActiveRecordEncryptionConfig
  DEV_DEFAULTS = {
    primary_key: "development_primary_key_32chars!",
    deterministic_key: "development_deterministic_32char",
    key_derivation_salt: "development_salt_must_be_32chars"
  }.freeze

  class MissingKey < StandardError; end

  def self.fetch(name, dev_default)
    value = ENV["AR_ENCRYPTION_#{name.upcase}"].presence
    return value if value
    return dev_default unless Rails.env.production?
    raise MissingKey, "AR_ENCRYPTION_#{name.upcase} must be set in production"
  end
end

Rails.application.config.active_record.encryption.primary_key =
  ActiveRecordEncryptionConfig.fetch(:primary_key, ActiveRecordEncryptionConfig::DEV_DEFAULTS[:primary_key])
Rails.application.config.active_record.encryption.deterministic_key =
  ActiveRecordEncryptionConfig.fetch(:deterministic_key, ActiveRecordEncryptionConfig::DEV_DEFAULTS[:deterministic_key])
Rails.application.config.active_record.encryption.key_derivation_salt =
  ActiveRecordEncryptionConfig.fetch(:key_derivation_salt, ActiveRecordEncryptionConfig::DEV_DEFAULTS[:key_derivation_salt])
