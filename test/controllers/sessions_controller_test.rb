require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:one) }

  test "new" do
    get new_session_path
    assert_response :success
  end

  # A no-2FA account skips the challenge but still lacks TOTP, so it lands on the checklist.
  test "create with valid credentials nudges an incomplete account to onboarding" do
    post session_path, params: { email_address: @user.email_address, password: "password" }

    assert_redirected_to onboarding_path
    assert cookies[:session_id]
  end

  test "create with invalid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "wrong" }

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
  end

  test "create is blocked for an unconfirmed user and resends confirmation" do
    unconfirmed = users(:unconfirmed)

    post session_path, params: { email_address: unconfirmed.email_address, password: "password" }

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
    assert_enqueued_email_with ConfirmationsMailer, :confirm, args: [ unconfirmed ]
  end

  test "create with a 2FA user redirects to the challenge without creating a session" do
    enable_2fa_for(@user)

    post session_path, params: { email_address: @user.email_address, password: "password" }

    assert_redirected_to new_totp_challenge_path
    assert_nil cookies[:session_id].presence
  end

  test "destroy" do
    sign_in_as(@user)

    delete session_path

    assert_redirected_to new_session_path
    assert_empty cookies[:session_id]
  end
end
