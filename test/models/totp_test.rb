require "test_helper"

class TotpTest < ActiveSupport::TestCase
  setup do
    @secret = Totp.generate_random_secret
    @totp = Totp.new(@secret)
  end

  test "generate_random_secret returns a fresh base32 secret each call" do
    assert_not_equal Totp.generate_random_secret, Totp.generate_random_secret
  end

  test "provisioning_uri embeds the issuer and label" do
    uri = @totp.provisioning_uri("user@example.com")

    assert_includes uri, "issuer=Authentication%20Hell"
    assert_includes uri, "user%40example.com"
    assert_includes uri, "secret=#{@secret}"
  end

  test "now returns the current code, which verify accepts" do
    assert @totp.verify(@totp.now)
  end

  test "verify returns the matched timestamp for a current code" do
    assert_kind_of Integer, @totp.verify(@totp.now)
  end

  test "verify rejects a wrong or blank code" do
    assert_nil @totp.verify("000000")
    assert_nil @totp.verify("")
    assert_nil @totp.verify(nil)
  end

  test "verify with after: rejects a replayed (or earlier) code" do
    code = @totp.now
    timestamp = @totp.verify(code)

    assert_nil @totp.verify(code, after: timestamp), "a code at or before `after` cannot be reused"
  end
end
