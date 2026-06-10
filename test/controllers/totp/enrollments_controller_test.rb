require "test_helper"

class Totp::EnrollmentsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:one) }

  test "new shows the QR code and secret" do
    sign_in_as(@user)

    get new_totp_enrollment_path

    assert_response :success
    assert_select "svg"
    # Confirm form opts out of Turbo so the success render (200, not a redirect) isn't rejected.
    assert_select "form[data-turbo='false']"
  end

  test "create with the correct code enables 2FA and shows recovery codes" do
    sign_in_as(@user)

    get new_totp_enrollment_path
    secret = css_select("code.break-all").first.text.strip
    post totp_enrollment_path, params: { code: ROTP::TOTP.new(secret).now }

    assert_response :success
    assert @user.reload.totp_enabled?
    assert_equal User::RECOVERY_CODE_COUNT, @user.recovery_codes_remaining
  end

  test "create with a wrong code does not enable 2FA" do
    sign_in_as(@user)

    get new_totp_enrollment_path
    post totp_enrollment_path, params: { code: "000000" }

    assert_redirected_to new_totp_enrollment_path
    assert_not @user.reload.totp_enabled?
  end

  test "new redirects when 2FA is already enabled" do
    enable_2fa_for(@user)
    sign_in_as(@user)

    get new_totp_enrollment_path

    assert_redirected_to totp_settings_path
  end

  test "requires authentication" do
    get new_totp_enrollment_path
    assert_redirected_to new_session_path
  end
end
