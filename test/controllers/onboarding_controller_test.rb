require "test_helper"

class OnboardingControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:one) }

  test "requires authentication" do
    get onboarding_path
    assert_redirected_to new_session_path
  end

  test "shows the checklist with the right step states for an incomplete account" do
    sign_in_as(@user) # password fixture, no TOTP or passkey
    enable_2fa_for(@user)

    get onboarding_path

    assert_response :success
    assert_select "h1", /Security/
    # Password and TOTP are done; the passkey step still offers to register one.
    assert_select "[data-controller=webauthn-registration]"
    assert_select "a[href=?]", new_totp_enrollment_path, false
  end

  test "passwordless account is offered the set-password form" do
    user = users(:passwordless)
    sign_in_as(user)

    get onboarding_path

    assert_response :success
    assert_select "form[action=?]", onboarding_password_path
  end

  test "stays accessible as a settings hub once fully set up" do
    enable_2fa_for(@user)
    enable_passkey_for(@user)
    sign_in_as(@user)

    get onboarding_path

    assert_response :success
    # Every method is configured, so each card links out to manage it.
    assert_select "a[href=?]", password_change_path
    assert_select "a[href=?]", webauthn_settings_path
    assert_select "a[href=?]", totp_settings_path
  end
end
