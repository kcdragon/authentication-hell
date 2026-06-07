require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "new" do
    get new_registration_path
    assert_response :success
  end

  test "create with valid attributes creates an unconfirmed user, sends confirmation, starts no session" do
    assert_difference -> { User.count }, 1 do
      post registration_path, params: { user: {
        username: "brandnew",
        email_address: "brandnew@example.com",
        password: "password",
        password_confirmation: "password"
      } }
    end

    user = User.find_by(email_address: "brandnew@example.com")
    assert_not_nil user
    assert_not user.confirmed?
    assert_enqueued_email_with ConfirmationsMailer, :confirm, args: [ user ]
    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
  end

  test "create with a duplicate email is rejected" do
    assert_no_difference -> { User.count } do
      post registration_path, params: { user: {
        username: "uniquename",
        email_address: users(:one).email_address,
        password: "password",
        password_confirmation: "password"
      } }
    end

    assert_response :unprocessable_entity
  end

  test "create with a case-insensitively duplicate username is rejected" do
    assert_no_difference -> { User.count } do
      post registration_path, params: { user: {
        username: users(:one).username.upcase,
        email_address: "unique@example.com",
        password: "password",
        password_confirmation: "password"
      } }
    end

    assert_response :unprocessable_entity
  end

  test "create with an invalid username format is rejected" do
    assert_no_difference -> { User.count } do
      post registration_path, params: { user: {
        username: "no spaces",
        email_address: "unique@example.com",
        password: "password",
        password_confirmation: "password"
      } }
    end

    assert_response :unprocessable_entity
  end

  test "create with mismatched passwords is rejected" do
    assert_no_difference -> { User.count } do
      post registration_path, params: { user: {
        username: "uniquename",
        email_address: "unique@example.com",
        password: "password",
        password_confirmation: "different"
      } }
    end

    assert_response :unprocessable_entity
  end
end
