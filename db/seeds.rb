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

user = User.find_or_initialize_by(email_address: "mike@example.com")
user.username = "mike"
user.password = User::DEV_PASSWORD
user.confirmed_at ||= Time.current
user.save!

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
