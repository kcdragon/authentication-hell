require "test_helper"

class PasskeyRegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "renders the passkey page without yet creating a user" do
    assert_no_difference -> { User.count } do
      post passkey_registration_path, params: { user: { username: "passkeynew", email_address: "passkeynew@example.com" } }
    end

    assert_response :success
  end

  test "validates the username and email before the passkey step" do
    post passkey_registration_path, params: { user: { username: users(:one).username.upcase, email_address: "unique@example.com" } }
    assert_response :unprocessable_entity
  end

  test "completing the passkey ceremony creates a passwordless, unconfirmed user" do
    post passkey_registration_path, params: { user: { username: "passkeynew", email_address: "passkeynew@example.com" } }

    assert_difference -> { User.count }, 1 do
      response = register_passkey_over_http(nickname: "Phone")
      assert_response :success
      assert_equal new_session_path, response.parsed_body["redirect"]
    end

    user = User.find_by(email_address: "passkeynew@example.com")
    assert user.passwordless?
    assert_not user.confirmed?
    assert_equal 1, user.webauthn_credentials.count
    assert_enqueued_email_with ConfirmationsMailer, :confirm, args: [ user ]
  end
end
