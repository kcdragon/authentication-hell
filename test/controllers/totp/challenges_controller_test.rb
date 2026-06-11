require "test_helper"

class Totp::ChallengesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @secret = enable_2fa_for(@user)
  end

  def start_pending_login
    post session_path, params: { email_address: @user.email_address, password: "password" }
    assert_redirected_to new_totp_challenge_path
  end

  test "new requires a pending login" do
    get new_totp_challenge_path
    assert_redirected_to new_session_path
  end

  test "new renders once a login is pending" do
    start_pending_login
    get new_totp_challenge_path
    assert_response :success
  end

  test "create with a valid TOTP code completes sign-in" do
    start_pending_login

    post totp_challenge_path, params: { code: ROTP::TOTP.new(@secret).now }

    assert_redirected_to root_path
    assert cookies[:session_id].present?
  end

  test "create with a valid recovery code completes sign-in once" do
    code = @user.generate_recovery_codes!.first
    start_pending_login

    post totp_challenge_path, params: { code: code }
    assert_redirected_to root_path
    assert cookies[:session_id].present?

    assert_not @user.reload.consume_recovery_code(code), "recovery code is single-use"
  end

  test "create preserves the return-to destination through the challenge" do
    get play_path
    assert_redirected_to new_session_path

    start_pending_login
    post totp_challenge_path, params: { code: ROTP::TOTP.new(@secret).now }

    assert_redirected_to play_path
  end

  test "create with an invalid code re-prompts and does not sign in" do
    start_pending_login

    post totp_challenge_path, params: { code: "000000" }

    assert_redirected_to new_totp_challenge_path
    assert_nil cookies[:session_id].presence
  end

  test "create without a pending login redirects to sign in" do
    post totp_challenge_path, params: { code: ROTP::TOTP.new(@secret).now }
    assert_redirected_to new_session_path
    assert_nil cookies[:session_id].presence
  end

  test "create after the pending window expires redirects to sign in" do
    start_pending_login

    travel 11.minutes do
      post totp_challenge_path, params: { code: ROTP::TOTP.new(@secret).now }
    end

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id].presence
  end
end
