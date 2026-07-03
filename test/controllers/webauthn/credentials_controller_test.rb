require "test_helper"

class Webauthn::CredentialsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:one) }

  test "a fully onboarded user registering a passkey is sent to passkey settings" do
    enable_2fa_for(@user)
    sign_in_as @user

    assert_difference -> { @user.webauthn_credentials.count }, 1 do
      response = register_passkey_over_http(nickname: "My Laptop")
      assert_response :success
      assert_equal webauthn_settings_path, response.parsed_body["redirect"]
    end

    assert_equal "My Laptop", @user.webauthn_credentials.last.nickname
  end

  test "registering a passkey mid-onboarding returns to the checklist" do
    sign_in_as @user

    response = register_passkey_over_http(nickname: "My Laptop")

    assert_response :success
    assert_equal onboarding_path, response.parsed_body["redirect"]
  end

  test "registration rejects a mismatched challenge" do
    sign_in_as @user

    post options_webauthn_credentials_path, as: :json
    client = WebAuthn::FakeClient.new(SessionTestHelper::WEBAUTHN_TEST_ORIGIN)
    forged = client.create(challenge: WebAuthn.configuration.encoder.encode("not-the-challenge"), user_verified: true)

    assert_no_difference -> { @user.webauthn_credentials.count } do
      post webauthn_credentials_path, params: { credential: forged }, as: :json
    end
    assert_response :unprocessable_entity
  end

  test "options require an enrollment context" do
    post options_webauthn_credentials_path, as: :json
    assert_response :unauthorized
  end

  test "a user can remove a passkey" do
    sign_in_as @user
    credential = @user.webauthn_credentials.create!(external_id: "ext", public_key: "key", nickname: "Old")

    assert_difference -> { @user.webauthn_credentials.count }, -1 do
      delete webauthn_credential_path(credential)
    end
    assert_redirected_to webauthn_settings_path
  end

  test "a passwordless user cannot remove their last passkey" do
    user = users(:passwordless)
    enable_passkey_for(user)
    sign_in_as user

    assert_no_difference -> { user.webauthn_credentials.count } do
      delete webauthn_credential_path(user.webauthn_credentials.first)
    end
    assert_redirected_to webauthn_settings_path
    assert_match(/last one/, flash[:alert])
  end
end
