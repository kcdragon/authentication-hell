require "test_helper"

class UserTest < ActiveSupport::TestCase
  def valid_attributes(**overrides)
    { username: "newuser", email_address: "new@example.com", password: "password" }.merge(overrides)
  end

  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "strips username" do
    user = User.new(username: "  spaced  ")
    assert_equal("spaced", user.username)
  end

  test "valid with valid attributes" do
    assert User.new(valid_attributes).valid?
  end

  test "username is required" do
    user = User.new(valid_attributes(username: ""))
    assert_not user.valid?
    assert user.errors[:username].any?
  end

  test "username length must be within 3..20" do
    assert_not User.new(valid_attributes(username: "ab")).valid?
    assert_not User.new(valid_attributes(username: "a" * 21)).valid?
    assert User.new(valid_attributes(username: "abc")).valid?
  end

  test "username format rejects disallowed characters" do
    assert_not User.new(valid_attributes(username: "has space")).valid?
    assert_not User.new(valid_attributes(username: "dash-name")).valid?
    assert User.new(valid_attributes(username: "ok_name1")).valid?
  end

  test "username is case-insensitively unique" do
    user = User.new(valid_attributes(username: users(:one).username.upcase))
    assert_not user.valid?
    assert user.errors[:username].any?
  end

  test "email_address is required and unique" do
    assert_not User.new(valid_attributes(email_address: "")).valid?
    assert_not User.new(valid_attributes(email_address: users(:one).email_address)).valid?
  end

  test "assigns a webauthn_id on creation" do
    user = User.create!(valid_attributes)
    assert user.webauthn_id.present?
  end

  test "a passwordless user is valid when it has a passkey and is flagged passwordless" do
    user = User.new(username: "pkuser", email_address: "pk@example.com")
    user.webauthn_credentials.build(external_id: "ext", public_key: "key", nickname: "Phone")

    assert user.valid?
    assert user.passwordless?
  end

  test "an account with neither a password nor a passkey is invalid" do
    user = User.new(username: "nofactor", email_address: "nf@example.com")

    assert_not user.valid?
    assert_includes user.errors[:base], "Add a password or a passkey to secure your account"
  end

  test "authenticate_by returns nil (not raises) for a passwordless user" do
    user = User.new(username: "pkuser", email_address: "pk@example.com")
    user.webauthn_credentials.build(external_id: "ext", public_key: "key", nickname: "Phone")
    user.save!

    assert_nil User.authenticate_by(email_address: "pk@example.com", password: "anything")
  end

  test "password confirmation is enforced when a password is set" do
    assert_not User.new(valid_attributes(password: "secret", password_confirmation: "different")).valid?
    assert User.new(valid_attributes(password: "secret", password_confirmation: "secret")).valid?
  end

  test "second_factor? is true with TOTP or a passkey" do
    user = users(:one)
    assert_not user.second_factor?

    user.webauthn_credentials.create!(external_id: "ext", public_key: "key", nickname: "Phone")
    assert user.second_factor?
  end

  test "onboarding_complete? requires a password, TOTP, and a passkey" do
    user = users(:one)
    assert_not user.onboarding_complete?

    user.enable_totp!(ROTP::Base32.random)
    assert_not user.onboarding_complete?

    user.webauthn_credentials.create!(external_id: "ext", public_key: "key", nickname: "Phone")
    assert user.onboarding_complete?
  end

  test "onboarding_complete? is false for a passwordless account with the other factors" do
    user = users(:passwordless)
    user.webauthn_credentials.create!(external_id: "ext", public_key: "key", nickname: "Phone")
    user.enable_totp!(ROTP::Base32.random)

    assert_not user.onboarding_complete?
  end

  test "confirmed? reflects confirmed_at" do
    assert users(:one).confirmed?
    assert_not users(:unconfirmed).confirmed?
  end

  test "confirm! sets confirmed_at once" do
    user = users(:unconfirmed)
    user.confirm!
    assert user.reload.confirmed?

    original = user.confirmed_at
    user.confirm!
    assert_equal original, user.reload.confirmed_at
  end

  test "email_confirmation token round-trips to the user" do
    user = users(:unconfirmed)
    token = user.generate_token_for(:email_confirmation)
    assert_equal user, User.find_by_token_for(:email_confirmation, token)
  end

  test "email_confirmation token is invalidated by an email change" do
    user = users(:unconfirmed)
    token = user.generate_token_for(:email_confirmation)
    user.update!(email_address: "changed@example.com")
    assert_nil User.find_by_token_for(:email_confirmation, token)
  end

  test "find_by_token_for! raises on a garbage token" do
    assert_raises ActiveSupport::MessageVerifier::InvalidSignature do
      User.find_by_token_for!(:email_confirmation, "not-a-real-token")
    end
  end

  test "enable_totp! stores an encrypted secret and flips the flag" do
    user = users(:one)
    secret = ROTP::Base32.random
    user.enable_totp!(secret)

    assert user.reload.totp_enabled?
    assert_equal secret, user.totp_secret
    assert_not_equal secret, user.ciphertext_for(:totp_secret), "secret should be stored encrypted"
  end

  test "verify_totp accepts a current code and rejects a wrong one" do
    user = users(:one)
    secret = ROTP::Base32.random
    user.enable_totp!(secret)

    assert user.verify_totp(ROTP::TOTP.new(secret).now)
    assert_not user.verify_totp("000000")
  end

  test "verify_totp rejects a replayed code" do
    user = users(:one)
    secret = ROTP::Base32.random
    user.enable_totp!(secret)
    code = ROTP::TOTP.new(secret).now

    assert user.verify_totp(code)
    assert_not user.verify_totp(code), "the same code cannot be used twice"
  end

  test "verify_totp returns false when 2FA is not enabled" do
    assert_not users(:one).verify_totp("123456")
  end

  test "generate_recovery_codes! returns plaintext codes and stores only digests" do
    user = users(:one)
    codes = user.generate_recovery_codes!

    assert_equal User::RECOVERY_CODE_COUNT, codes.size
    assert_equal codes.size, user.recovery_codes_remaining
    assert user.recovery_codes.none? { |rc| rc.code_digest.in?(codes) }, "codes must be hashed at rest"
  end

  test "generate_recovery_codes! replaces any existing codes" do
    user = users(:one)
    first = user.generate_recovery_codes!
    user.generate_recovery_codes!

    assert_not user.consume_recovery_code(first.first), "old codes are invalidated on regeneration"
  end

  test "consume_recovery_code works once then is rejected" do
    user = users(:one)
    code = user.generate_recovery_codes!.first

    assert user.consume_recovery_code(code)
    assert_not user.consume_recovery_code(code)
    assert_equal User::RECOVERY_CODE_COUNT - 1, user.recovery_codes_remaining
  end

  test "consume_recovery_code rejects an unknown code" do
    user = users(:one)
    user.generate_recovery_codes!
    assert_not user.consume_recovery_code("not-a-real-code")
  end

  test "valid with an acceptable avatar attached" do
    user = users(:one)
    user.avatar.attach(io: Rails.root.join("public/icon.png").open, filename: "icon.png", content_type: "image/png")
    assert user.valid?
  end

  test "rejects a non-image avatar" do
    user = users(:one)
    user.avatar.attach(io: StringIO.new("nope"), filename: "a.txt", content_type: "text/plain")
    assert_not user.valid?
    assert user.errors[:avatar].any?
  end

  test "rejects an oversized avatar" do
    user = users(:one)
    user.avatar.attach(io: StringIO.new("x" * (User::AVATAR_MAX_SIZE + 1)), filename: "big.png", content_type: "image/png")
    assert_not user.valid?
    assert user.errors[:avatar].any?
  end

  test "record_level_completed advances the high-water mark and returns true" do
    user = users(:one)
    assert user.record_level_completed(2)
    assert_equal 2, user.reload.highest_level_completed
  end

  test "record_level_completed never moves backward and returns false" do
    user = users(:one)
    user.update!(highest_level_completed: 2)

    assert_not user.record_level_completed(1)
    assert_equal 2, user.reload.highest_level_completed
  end

  test "grant_achievement is idempotent and leaves the user savable when already earned" do
    user = users(:one)
    user.grant_achievement(:level_0_complete)

    assert_no_difference -> { user.earned_achievements.count } do
      assert_nil user.grant_achievement(:level_0_complete), "a re-grant returns nil, not a record"
    end

    assert_nothing_raised { user.update!(now_playing_level: 1) }
  end

  test "reset_progress! clears levels and earned achievements" do
    user = users(:one)
    user.update!(highest_level_completed: 2, now_playing_level: 1)
    user.grant_achievement(:password_survivor)

    user.reset_progress!

    assert_nil user.reload.highest_level_completed
    assert_nil user.now_playing_level
    assert_equal 0, user.earned_achievements.count
  end

  test "reset_progress! clears the certificate token and award date so old links stop resolving" do
    user = users(:one)
    user.ensure_certificate_token!
    user.mark_certified!

    user.reset_progress!

    assert_nil user.reload.certificate_token
    assert_nil user.certificate_awarded_at
  end

  test "ensure_certificate_token! mints a stable, unguessable token" do
    user = users(:one)
    assert_nil user.certificate_token

    token = user.ensure_certificate_token!

    assert_predicate token, :present?
    assert_equal token, user.reload.certificate_token
    assert_equal token, user.ensure_certificate_token!, "the token is stable once minted"
  end

  test "mark_certified! stamps the award date once and doesn't move it on replays" do
    user = users(:one)

    user.mark_certified!
    first = user.reload.certificate_awarded_at
    assert_predicate first, :present?

    travel 1.day do
      user.mark_certified!
      assert_equal first, user.reload.certificate_awarded_at, "the date is fixed at first completion"
    end
  end

  test "current_level is the first level before any are cleared" do
    user = users(:one)
    assert_nil user.highest_level_completed
    assert_equal 0, user.current_level.number
  end

  test "current_level advances to the level after the furthest cleared" do
    user = users(:one)
    user.update!(highest_level_completed: 0)
    assert_equal 1, user.current_level.number
  end

  test "current_level stays on the last level once everything is cleared" do
    user = users(:one)
    user.update!(highest_level_completed: GameLevel.all.map(&:number).max)
    assert_equal GameLevel.all.map(&:number).max, user.current_level.number
  end

  test "current_level clamps to the last level when highest_level_completed exceeds it" do
    user = users(:one)
    user.update!(highest_level_completed: GameLevel.all.map(&:number).max + 1)
    assert_equal GameLevel.all.map(&:number).max, user.current_level.number
  end

  test "now_playing falls back to current_level when unreported" do
    user = users(:one)
    user.update!(highest_level_completed: 0)
    assert_nil user.now_playing_level
    assert_equal 1, user.now_playing
  end

  test "now_playing reflects a reported level, even a replayed cleared one" do
    user = users(:one)
    user.update!(highest_level_completed: 2, now_playing_level: 0)
    assert_equal 0, user.now_playing
  end

  test "beat_game? is true once the graduation level is cleared, without the bonus level" do
    user = users(:one)
    graduation = GameLevel.graduation.number

    assert_not user.beat_game?
    user.update!(highest_level_completed: graduation - 1)
    assert_not user.beat_game?
    user.update!(highest_level_completed: graduation)
    assert user.beat_game?
  end

  test "reset_progress! clears game stats" do
    user = users(:one)
    GameStat.record_reauth_totp(user)
    GameStat.record_defeat_buffering(user)

    user.reset_progress!

    assert_equal 0, user.game_stats.count
  end

  test "reset_progress! clears level completions" do
    user = users(:one)
    LevelCompletion.record(user, 1, 42_000)

    user.reset_progress!

    assert_equal 0, user.level_completions.count
  end

  test "disable_totp! clears the secret, flag, and recovery codes" do
    user = users(:one)
    user.enable_totp!(ROTP::Base32.random)
    user.generate_recovery_codes!

    user.disable_totp!

    assert_not user.reload.totp_enabled?
    assert_nil user.totp_secret
    assert_nil user.last_totp_at
    assert_equal 0, user.recovery_codes.count
  end
end
