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
end
