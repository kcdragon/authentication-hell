require "test_helper"

class TotpHelperTest < ActionView::TestCase
  include ApplicationHelper # dev_totp_prefill delegates to dev_prefills_enabled?

  setup { @user = users(:one) }

  test "dev_totp_prefill returns the user's current code in development" do
    secret = ROTP::Base32.random
    @user.enable_totp!(secret)

    in_development do
      assert_equal ROTP::TOTP.new(secret).now, dev_totp_prefill(@user)
    end
  end

  test "dev_totp_prefill returns nil in development when the user isn't enrolled" do
    in_development do
      assert_nil dev_totp_prefill(@user)
    end
  end

  test "dev_totp_prefill returns nil outside development even when enrolled" do
    @user.enable_totp!(ROTP::Base32.random)

    assert_nil dev_totp_prefill(@user)
  end

  private

  def in_development
    original = Rails.env
    Rails.env = "development"
    yield
  ensure
    Rails.env = original
  end
end
