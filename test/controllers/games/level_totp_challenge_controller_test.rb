require "test_helper"

class Games::LevelTotpChallengeControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier
  include Games::LevelTotpHelper
  include ActiveSupport::Testing::TimeHelpers

  setup { @user = users(:one) }

  test "start requires authentication" do
    post games_level_totp_start_url
    assert_redirected_to new_session_path
  end

  test "start mints a temporary authenticator and broadcasts its QR toast" do
    sign_in_as(@user)

    streams = capture_turbo_stream_broadcasts([ @user, :toasts ]) do
      post games_level_totp_start_url
    end

    assert_response :no_content
    assert_equal 1, streams.size
    assert_equal "append", streams.first["action"]
    assert_includes streams.first.to_html, "Link a temporary authenticator"
    assert @user.sessions.last.temporary_totp_challenge.present?
  end

  test "status reports a fresh, unlinked challenge" do
    sign_in_as(@user)
    get games_level_totp_status_url
    assert_equal({ "registered" => false, "streak" => 0, "complete" => false }, response.parsed_body)
  end

  test "register links the authenticator with a valid code" do
    secret = start_and_read_secret

    post games_level_totp_register_url, params: { code: ROTP::TOTP.new(secret).now }, as: :turbo_stream

    assert_response :success
    assert_includes response.body, "Authenticator linked"
    get games_level_totp_status_url
    assert_equal true, response.parsed_body["registered"]
  end

  test "register rejects a bad code and keeps showing the QR" do
    start_and_read_secret

    post games_level_totp_register_url, params: { code: "000000" }, as: :turbo_stream

    assert_includes response.body, "Invalid code"
    get games_level_totp_status_url
    assert_equal false, response.parsed_body["registered"]
  end

  test "three consecutive codes complete the challenge and remove the toast" do
    secret = start_and_read_secret
    totp = ROTP::TOTP.new(secret)
    base = 1_700_000_000 - (1_700_000_000 % 30)

    travel_to(Time.at(base)) do
      post games_level_totp_register_url, params: { code: totp.now }, as: :turbo_stream
      submit(totp.now)
      assert_equal 1, response.parsed_body["streak"]
    end
    travel_to(Time.at(base + 30)) do
      submit(totp.now)
      assert_equal 2, response.parsed_body["streak"]
    end

    streams = nil
    travel_to(Time.at(base + 60)) do
      streams = capture_turbo_stream_broadcasts([ @user, :toasts ]) { submit(totp.now) }
    end

    assert_equal({ "ok" => true, "streak" => 3, "complete" => true }, response.parsed_body)
    assert(streams.any? { |s| s["action"] == "remove" })
  end

  test "a valid code broadcasts an accepted toast with the remaining count" do
    secret = start_and_read_secret
    totp = ROTP::TOTP.new(secret)

    travel_to(Time.at(1_700_000_000)) do
      post games_level_totp_register_url, params: { code: totp.now }, as: :turbo_stream
      streams = capture_turbo_stream_broadcasts([ @user, :toasts ]) { submit(totp.now) }
      html = streams.map(&:to_html).join
      assert_includes html, "Code accepted"
      assert_includes html, "2 more in a row"
    end
  end

  test "an incorrect code broadcasts a streak-reset toast" do
    secret = start_and_read_secret
    travel_to(Time.at(1_700_000_000)) do
      post games_level_totp_register_url, params: { code: ROTP::TOTP.new(secret).now }, as: :turbo_stream
      streams = capture_turbo_stream_broadcasts([ @user, :toasts ]) { submit("000000") }

      assert_equal false, response.parsed_body["ok"]
      assert_includes streams.map(&:to_html).join, "streak is reset"
    end
  end

  test "status omits dev codes outside development" do
    register_fresh_challenge
    get games_level_totp_status_url
    assert_nil response.parsed_body["codes"]
  end

  test "status reveals the upcoming codes when dev prefills are enabled" do
    secret = register_fresh_challenge
    original_env = Rails.env
    Rails.env = "development"
    travel_to(Time.at(1_700_000_000)) do
      get games_level_totp_status_url
      assert_equal 3, response.parsed_body["codes"].length
      assert_equal ROTP::TOTP.new(secret).now, response.parsed_body["codes"].first
    end
  ensure
    Rails.env = original_env
  end

  private

  def register_fresh_challenge
    secret = start_and_read_secret
    travel_to(Time.at(1_700_000_000)) do
      post games_level_totp_register_url, params: { code: ROTP::TOTP.new(secret).now }, as: :turbo_stream
    end
    secret
  end

  def start_and_read_secret
    sign_in_as(@user)
    streams = capture_turbo_stream_broadcasts([ @user, :toasts ]) { post games_level_totp_start_url }
    streams.first.to_html[/data-secret="([A-Z2-7]+)"/, 1]
  end

  def submit(code)
    post games_level_totp_submit_url, params: { code: code }
  end
end
