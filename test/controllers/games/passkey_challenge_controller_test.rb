require "test_helper"

class Games::PasskeyChallengeControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier
  include Games::PasskeyHelper

  setup { @user = users(:one) }

  test "start requires authentication" do
    post games_passkey_start_url
    assert_redirected_to new_session_path
  end

  test "start broadcasts the passkey challenge toast and locks the player" do
    sign_in_as(@user)

    streams = capture_turbo_stream_broadcasts([ @user, :toasts ]) do
      post games_passkey_start_url
    end

    assert_equal 1, streams.size
    broadcast = streams.first
    assert_equal "append", broadcast["action"]
    assert_equal Game::Toasts::PERMANENT_CONTAINER, broadcast["target"]
    assert_includes broadcast.to_html, "You bumped into the passkey enemy!"

    assert_response :no_content

    get games_passkey_status_url
    assert_equal({ "locked" => true }, response.parsed_body)
  end

  test "status requires authentication" do
    get games_passkey_status_url
    assert_redirected_to new_session_path
  end

  test "status reports unlocked until a collision locks the player" do
    sign_in_as(@user)

    get games_passkey_status_url
    assert_equal({ "locked" => false }, response.parsed_body)

    post games_passkey_start_url
    get games_passkey_status_url
    assert_equal({ "locked" => true }, response.parsed_body)
  end

  test "complete requires authentication" do
    post games_passkey_complete_url
    assert_redirected_to new_session_path
  end

  test "a valid passkey assertion clears the lock and broadcasts the toast removal" do
    client = enable_passkey_for(@user)
    sign_in_as(@user)
    post games_passkey_start_url

    post games_passkey_options_url, as: :json
    assertion = client.get(challenge: response.parsed_body["challenge"], user_verified: true)

    streams = capture_turbo_stream_broadcasts([ @user, :toasts ]) do
      post games_passkey_complete_url, params: { credential: assertion }, as: :json
    end

    assert_response :success
    assert_equal({ "ok" => true }, response.parsed_body)
    assert_equal "remove", streams.first["action"]

    get games_passkey_status_url
    assert_equal({ "locked" => false }, response.parsed_body)
  end

  test "completing the challenge awards the survivor achievement and toasts it" do
    client = enable_passkey_for(@user)
    sign_in_as(@user)
    post games_passkey_start_url

    post games_passkey_options_url, as: :json
    assertion = client.get(challenge: response.parsed_body["challenge"], user_verified: true)

    streams = nil
    assert_difference -> { @user.earned_achievements.count }, 1 do
      streams = capture_turbo_stream_broadcasts([ @user, :toasts ]) do
        post games_passkey_complete_url, params: { credential: assertion }, as: :json
      end
    end
    assert @user.earned?(:passkey_survivor)
    assert(streams.any? { |s| s.to_html.include?("Achievement unlocked") })
  end

  test "failing the challenge awards nothing" do
    other_client = enable_passkey_for(users(:two))
    sign_in_as(@user)
    post games_passkey_start_url

    post games_passkey_options_url, as: :json
    assertion = other_client.get(challenge: response.parsed_body["challenge"], user_verified: true)

    assert_no_difference -> { @user.earned_achievements.count } do
      post games_passkey_complete_url, params: { credential: assertion }, as: :json
    end
  end

  test "an assertion signed against a forged challenge keeps the player locked" do
    client = enable_passkey_for(@user)
    sign_in_as(@user)
    post games_passkey_start_url

    post games_passkey_options_url, as: :json
    forged = client.get(
      challenge: WebAuthn.configuration.encoder.encode("not-the-challenge"),
      user_verified: true
    )

    post games_passkey_complete_url, params: { credential: forged }, as: :json

    assert_response :unprocessable_entity
    assert response.parsed_body["error"].present?

    get games_passkey_status_url
    assert_equal({ "locked" => true }, response.parsed_body)
  end

  test "complete cannot clear the lock when no collision is pending" do
    client = enable_passkey_for(@user)
    sign_in_as(@user)

    post games_passkey_options_url, as: :json
    assertion = client.get(challenge: response.parsed_body["challenge"], user_verified: true)

    post games_passkey_complete_url, params: { credential: assertion }, as: :json
    assert_response :unprocessable_entity
  end

  test "complete cannot clear the lock for a player without a registered passkey" do
    other_client = enable_passkey_for(users(:two))
    sign_in_as(@user)
    post games_passkey_start_url

    post games_passkey_options_url, as: :json
    assertion = other_client.get(challenge: response.parsed_body["challenge"], user_verified: true)

    post games_passkey_complete_url, params: { credential: assertion }, as: :json

    assert_response :unprocessable_entity

    get games_passkey_status_url
    assert_equal({ "locked" => true }, response.parsed_body)
  end
end
