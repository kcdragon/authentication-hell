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
user.password = User::DEV_PASSWORD
user.webauthn_id = dev_passkey[:webauthn_id] if dev_passkey
user.confirmed_at ||= Time.current
user.super_admin = true
user.save!

if dev_passkey
  user.webauthn_credentials.find_or_create_by!(external_id: dev_passkey[:external_id]) do |c|
    c.public_key = dev_passkey[:public_key]
    c.sign_count = 0                       # 1Password reports 0; verify accepts 0 vs stored 0
    c.nickname   = "1Password (dev seed)"
  end
end

# A spread of players to exercise the leaderboard. The dev user (mike) has beaten the
# game — furthest and fully decorated. Among the rest, level and achievement count are
# deliberately uncorrelated (e.g. ada is further than grace but less decorated, grace is
# the reverse) so the two sort columns produce visibly different orderings.
# `times` seeds the Times tab: best_ms per level_number, tuned so mike isn't fastest
# everywhere — level 0 fills a four-row board, level 1 a two-row one, levels 2-3 a single
# row each, and every later level shows its empty state.
# Idempotent — grant_achievement/record_level_completed and the fastest-wins upsert are no-ops once set.
leaderboard_players = [
  { username: "ada",      level: 1,   achievements: %w[ passkey_survivor ],
    times: { 0 => 38_900, 1 => 64_500 } },
  { username: "mike",     level: 3,   achievements: %w[ level_0_complete level_1_complete level_2_complete level_3_complete password_survivor totp_survivor passkey_survivor graduate ],
    times: { 0 => 45_000, 1 => 58_100, 2 => 72_400, 3 => 88_700 } },
  { username: "grace",    level: 0,   achievements: Achievement.keys,
    times: { 0 => 41_200 } },
  { username: "linus",    level: 0,   achievements: %w[ level_0_complete password_survivor totp_survivor passkey_survivor ],
    times: { 0 => 52_300 } },
  { username: "margaret", level: nil, achievements: %w[ password_survivor totp_survivor ],
    times: {} }
]

leaderboard_players.each do |attrs|
  player = User.find_or_initialize_by(email_address: "#{attrs[:username]}@example.com")
  player.username = attrs[:username]
  player.password ||= User::DEV_PASSWORD
  player.confirmed_at ||= Time.current
  player.save!

  player.record_level_completed(attrs[:level]) if attrs[:level]
  attrs[:achievements].each { |key| player.grant_achievement(key) }
  attrs[:times].each { |level_number, ms| LevelCompletion.record(player, level_number, ms) }
end

# The dev user has beaten the game — issue the certificate so the claim link resolves.
user.mark_certified!
user.ensure_certificate_token!

# Pre-enroll the dev user with a fixed secret (JBSWY3DPEHPK3PXP) so a fresh DB
# doesn't force re-enrollment — add it to your authenticator once. Dev only.
if Rails.env.development?
  dev_totp_secret = "JBSWY3DPEHPK3PXP" # dev seed fixture, not a real secret

  user.enable_totp!(dev_totp_secret) unless user.totp_enabled? && user.totp_secret == dev_totp_secret
end
