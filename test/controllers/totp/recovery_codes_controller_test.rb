require "test_helper"

class Totp::RecoveryCodesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @secret = enable_2fa_for(@user)
  end

  test "create regenerates the codes when confirmed with a current code" do
    old_codes = @user.recovery_codes.pluck(:code_digest)
    sign_in_as(@user)

    post totp_recovery_codes_path, params: { code: ROTP::TOTP.new(@secret).now }

    assert_response :success
    assert_not_equal old_codes.sort, @user.reload.recovery_codes.pluck(:code_digest).sort
    assert_equal User::RECOVERY_CODE_COUNT, @user.recovery_codes_remaining
  end

  test "create without confirmation does not regenerate" do
    old_codes = @user.recovery_codes.pluck(:code_digest).sort
    sign_in_as(@user)

    post totp_recovery_codes_path, params: { code: "000000" }

    assert_redirected_to totp_settings_path
    assert_equal old_codes, @user.reload.recovery_codes.pluck(:code_digest).sort
  end

  test "redirects when 2FA is not enabled" do
    @user.disable_totp!
    sign_in_as(@user)

    post totp_recovery_codes_path, params: { code: "000000" }

    assert_redirected_to totp_settings_path
  end

  test "requires authentication" do
    post totp_recovery_codes_path
    assert_redirected_to new_session_path
  end
end
