require "test_helper"

class Totp::SettingsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:one) }

  test "show reflects the disabled state" do
    sign_in_as(@user)
    get totp_settings_path
    assert_response :success
    assert_select "a", text: /Set up two-factor authentication/
  end

  test "show reflects the enabled state with remaining recovery codes" do
    enable_2fa_for(@user)
    sign_in_as(@user)

    get totp_settings_path

    assert_response :success
    assert_match "Enabled", response.body
  end

  test "destroy with a valid code disables 2FA" do
    secret = enable_2fa_for(@user)
    sign_in_as(@user)

    delete totp_settings_path, params: { code: ROTP::TOTP.new(secret).now }

    assert_redirected_to totp_settings_path
    assert_not @user.reload.totp_enabled?
  end

  test "destroy with the account password disables 2FA" do
    enable_2fa_for(@user)
    sign_in_as(@user)

    delete totp_settings_path, params: { password: "password" }

    assert_redirected_to totp_settings_path
    assert_not @user.reload.totp_enabled?
  end

  test "destroy without confirmation leaves 2FA enabled" do
    enable_2fa_for(@user)
    sign_in_as(@user)

    delete totp_settings_path, params: { code: "000000" }

    assert_redirected_to totp_settings_path
    assert @user.reload.totp_enabled?
  end

  test "requires authentication" do
    get totp_settings_path
    assert_redirected_to new_session_path
  end
end
