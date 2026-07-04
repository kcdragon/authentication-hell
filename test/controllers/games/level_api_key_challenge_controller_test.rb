require "test_helper"

class Games::LevelApiKeyChallengeControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier
  include Games::LevelApiKeyHelper

  setup { @user = users(:one) }

  test "start requires authentication" do
    post games_level_api_key_start_url
    assert_redirected_to new_session_path
  end

  test "start broadcasts the mint prompt toast without creating a key" do
    sign_in_as(@user)

    streams = capture_turbo_stream_broadcasts([ @user, :toasts ]) do
      post games_level_api_key_start_url
    end

    assert_response :no_content
    assert_equal 1, streams.size
    assert_equal "append", streams.first["action"]
    assert_includes streams.first.to_html, "Mint API key"
    assert_nil @user.sessions.last.temporary_api_key_challenge
  end

  test "start discards any previous key so it no longer authenticates" do
    sign_in_as(@user)
    session = @user.sessions.last
    old_token = session.create_temporary_api_key_challenge!.token

    post games_level_api_key_start_url

    assert_nil TemporaryApiKeyChallenge.find_by(token: old_token)
  end

  test "create mints the key and replaces the toast with the curl command" do
    sign_in_as(@user)
    post games_level_api_key_start_url

    post games_level_api_key_create_url, as: :turbo_stream

    assert_response :success
    challenge = @user.sessions.last.temporary_api_key_challenge
    assert challenge.present?
    assert_includes response.body, %(data-api-key="#{challenge.token}")
    assert_includes response.body, "curl -X POST http://www.example.com/api/bridge"
    assert_includes response.body, "Authorization: Bearer #{challenge.token}"
  end

  test "create is idempotent while a key already exists" do
    sign_in_as(@user)
    post games_level_api_key_create_url, as: :turbo_stream
    token = @user.sessions.last.temporary_api_key_challenge.token

    post games_level_api_key_create_url, as: :turbo_stream

    assert_equal token, @user.sessions.last.reload.temporary_api_key_challenge.token
  end

  test "status is closed before the bridge opens and open after" do
    sign_in_as(@user)
    post games_level_api_key_create_url, as: :turbo_stream

    get games_level_api_key_status_url
    assert_equal({ "opened" => false }, response.parsed_body)

    @user.sessions.last.temporary_api_key_challenge.open!
    get games_level_api_key_status_url
    assert_equal({ "opened" => true }, response.parsed_body)
  end

  test "status reports closed with no challenge at all" do
    sign_in_as(@user)
    get games_level_api_key_status_url
    assert_equal({ "opened" => false }, response.parsed_body)
  end
end
