require "test_helper"

class Api::BridgeControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier
  include Games::LevelApiKeyHelper

  setup do
    @user = users(:one)
    @session = @user.sessions.create!
    @challenge = @session.create_temporary_api_key_challenge!
  end

  test "no authorization header returns 401 with a hint" do
    post api_bridge_url

    assert_response :unauthorized
    assert_equal "missing_token", response.parsed_body["error"]
    assert_includes response.parsed_body["hint"], "Authorization: Bearer"
  end

  test "an unknown token returns 401" do
    post api_bridge_url, headers: { "Authorization" => "Bearer ah_wrong" }

    assert_response :unauthorized
    assert_equal "invalid_token", response.parsed_body["error"]
  end

  test "a non-bearer authorization scheme returns 401" do
    post api_bridge_url, headers: { "Authorization" => "Basic #{@challenge.token}" }

    assert_response :unauthorized
    assert_equal "missing_token", response.parsed_body["error"]
  end

  test "a valid bearer token opens the bridge and updates the toast" do
    streams = capture_turbo_stream_broadcasts([ @user, :toasts ]) do
      post api_bridge_url, headers: { "Authorization" => "Bearer #{@challenge.token}" }
    end

    assert_response :success
    assert_equal "extended", response.parsed_body["bridge"]
    assert @challenge.reload.opened?

    replace = streams.find { |s| s["action"] == "replace" }
    assert_equal level_api_key_challenge_toast_id(@user), replace["target"]
    assert_includes replace.to_html, "Bridge extended"
  end

  test "a repeat call is an idempotent 200" do
    @challenge.open!
    opened_at = @challenge.opened_at

    post api_bridge_url, headers: { "Authorization" => "Bearer #{@challenge.token}" }

    assert_response :success
    assert_includes response.parsed_body["message"], "already"
    assert_equal opened_at, @challenge.reload.opened_at
  end

  test "authenticates by token alone, with no session cookie" do
    reset!
    post api_bridge_url, headers: { "Authorization" => "Bearer #{@challenge.token}" }

    assert_response :success
    assert @challenge.reload.opened?
  end
end
