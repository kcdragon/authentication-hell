require "test_helper"

class Onboarding::PasswordsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:passwordless) }

  test "requires authentication" do
    post onboarding_password_path, params: { user: { password: "secret", password_confirmation: "secret" } }
    assert_redirected_to new_session_path
  end

  test "sets a password and returns to the checklist" do
    sign_in_as(@user)

    post onboarding_password_path, params: { user: { password: "secretpassword", password_confirmation: "secretpassword" } }

    assert_redirected_to onboarding_path
    assert @user.reload.password_digest.present?
    assert @user.authenticate("secretpassword")
  end

  test "rejects a mismatched confirmation" do
    sign_in_as(@user)

    post onboarding_password_path, params: { user: { password: "secretpassword", password_confirmation: "nope" } }

    assert_response :unprocessable_entity
    assert @user.reload.passwordless?
  end

  test "rejects a blank password" do
    sign_in_as(@user)

    post onboarding_password_path, params: { user: { password: "", password_confirmation: "" } }

    assert_response :unprocessable_entity
    assert @user.reload.passwordless?
  end
end
