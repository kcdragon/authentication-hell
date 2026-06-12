# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Never seed outside development/test — the dev TOTP secret below must not reach production.
return unless Rails.env.local?

# Public half of a 1Password passkey registered once against http://localhost:3000, kept in
# development credentials (bin/rails credentials:edit --environment development) under
# dev_passkey. 1Password holds the private key, so reseeding this lets the same passkey log
# in after every DB reset — no re-registration. Absent (e.g. CI without the dev key) → skipped.
# To (re)capture after registering a passkey as mike@example.com:
#   bin/rails runner 'u = User.find_by(email_address: "mike@example.com"); c = u.webauthn_credentials.last; puts u.webauthn_id; puts c.external_id; puts c.public_key'
dev_passkey = Rails.application.credentials.dev_passkey if Rails.env.development?

user = User.find_or_initialize_by(email_address: "mike@example.com")
user.username = "mike"
user.password = "password"
user.webauthn_id = dev_passkey[:webauthn_id] if dev_passkey
user.confirmed_at ||= Time.current
user.save!

if dev_passkey
  user.webauthn_credentials.find_or_create_by!(external_id: dev_passkey[:external_id]) do |c|
    c.public_key = dev_passkey[:public_key]
    c.sign_count = 0                       # 1Password reports 0; verify accepts 0 vs stored 0
    c.nickname   = "1Password (dev seed)"
  end
end

# Pre-enroll the dev user with a fixed secret so a fresh DB doesn't force
# re-enrollment — add it to your authenticator once (printed below). Dev only.
if Rails.env.development?
  dev_totp_secret = "JBSWY3DPEHPK3PXP" # dev seed fixture, not a real secret

  user.enable_totp!(dev_totp_secret) unless user.totp_enabled? && user.totp_secret == dev_totp_secret

  provisioning_uri = ROTP::TOTP.new(dev_totp_secret, issuer: User::TOTP_ISSUER)
    .provisioning_uri(user.email_address)
  puts "TOTP enabled for #{user.email_address}. Add this to your authenticator app once:"
  puts "  secret:  #{dev_totp_secret}"
  puts "  otpauth: #{provisioning_uri}"
end
