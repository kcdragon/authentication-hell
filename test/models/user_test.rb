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
