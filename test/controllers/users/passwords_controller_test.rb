require "test_helper"

class Users::PasswordsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:one) }

  test "show requires authentication" do
    get password_change_path
    assert_redirected_to new_session_path
  end

  test "show renders for a signed-in user" do
    sign_in_as(@user)
    get password_change_path
    assert_response :success
  end

  test "update changes the password and keeps the user signed in" do
    sign_in_as(@user)

    assert_changes -> { @user.reload.password_digest } do
      patch password_change_path, params: {
        current_password: "password",
        user: { password: "new-secret", password_confirmation: "new-secret" }
      }
    end

    assert_redirected_to password_change_path
    follow_redirect!
    assert_flash "Password updated"
  end

  test "update keeps the current session and destroys other sessions" do
    sign_in_as(@user)
    current_session = Current.session
    other_session = @user.sessions.create!

    patch password_change_path, params: {
      current_password: "password",
      user: { password: "new-secret", password_confirmation: "new-secret" }
    }

    assert @user.sessions.exists?(current_session.id)
    assert_not @user.sessions.exists?(other_session.id)
  end

  test "update with the wrong current password is rejected" do
    sign_in_as(@user)

    assert_no_changes -> { @user.reload.password_digest } do
      patch password_change_path, params: {
        current_password: "wrong",
        user: { password: "new-secret", password_confirmation: "new-secret" }
      }
    end

    assert_response :unprocessable_entity
    assert_flash "Current password is incorrect"
  end

  test "update with a mismatched confirmation is rejected" do
    sign_in_as(@user)

    assert_no_changes -> { @user.reload.password_digest } do
      patch password_change_path, params: {
        current_password: "password",
        user: { password: "new-secret", password_confirmation: "different" }
      }
    end

    assert_response :unprocessable_entity
  end

  test "a passwordless user can set a password without a current password" do
    user = users(:passwordless)
    enable_passkey_for(user)
    sign_in_as(user)

    assert_changes -> { user.reload.password_digest } do
      patch password_change_path, params: {
        user: { password: "new-secret", password_confirmation: "new-secret" }
      }
    end

    assert_redirected_to password_change_path
  end

  private

  def assert_flash(text)
    assert_select "div", /#{text}/
  end
end
