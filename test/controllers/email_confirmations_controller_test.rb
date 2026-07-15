require "test_helper"

class EmailConfirmationsControllerTest < ActionDispatch::IntegrationTest
  test "new" do
    get new_email_confirmation_path
    assert_response :success
  end

  test "pending shows the address the confirmation was sent to" do
    post registration_path, params: { user: {
      username: "pendinguser",
      email_address: "pendinguser@example.com",
      password: "password",
      password_confirmation: "password"
    } }

    get confirmation_pending_path

    assert_response :success
    assert_select "body", /pendinguser@example.com/
  end

  test "show with a valid token confirms the user" do
    user = users(:unconfirmed)
    token = user.generate_token_for(:email_confirmation)

    get email_confirmation_path(token: token)

    assert user.reload.confirmed?
    assert_redirected_to new_session_path
  end

  test "show with an invalid token redirects to the resend form" do
    get email_confirmation_path(token: "garbage")
    assert_redirected_to new_email_confirmation_path
  end

  test "create resends for an existing unconfirmed user" do
    user = users(:unconfirmed)

    post email_confirmation_path, params: { email_address: user.email_address }

    assert_enqueued_email_with ConfirmationsMailer, :confirm, args: [ user ]
    assert_redirected_to confirmation_pending_path
    assert_equal user.email_address, session[:pending_confirmation_email]
  end

  test "create does not resend for an already confirmed user" do
    post email_confirmation_path, params: { email_address: users(:one).email_address }

    assert_enqueued_emails 0
    assert_redirected_to confirmation_pending_path
  end

  test "create does not send for an unknown email" do
    post email_confirmation_path, params: { email_address: "nobody@example.com" }

    assert_enqueued_emails 0
    assert_redirected_to confirmation_pending_path
  end
end
