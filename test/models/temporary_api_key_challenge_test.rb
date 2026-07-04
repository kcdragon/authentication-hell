require "test_helper"

class TemporaryApiKeyChallengeTest < ActiveSupport::TestCase
  setup do
    @session = users(:one).sessions.create!
    @challenge = @session.create_temporary_api_key_challenge!
  end

  test "generates a prefixed token on create" do
    assert @challenge.token.start_with?(TemporaryApiKeyChallenge::TOKEN_PREFIX)
    assert_operator @challenge.token.length, :>, 20
  end

  test "tokens are unique per challenge" do
    other = users(:two).sessions.create!.create_temporary_api_key_challenge!
    refute_equal @challenge.token, other.token
  end

  test "open! stamps opened_at once and is idempotent" do
    refute @challenge.opened?

    @challenge.open!
    assert @challenge.opened?
    first_opened_at = @challenge.opened_at

    @challenge.open!
    assert_equal first_opened_at, @challenge.reload.opened_at
  end

  test "token can be looked up for bearer authentication" do
    assert_equal @challenge, TemporaryApiKeyChallenge.find_by(token: @challenge.token)
    assert_nil TemporaryApiKeyChallenge.find_by(token: "ah_wrong")
  end

  test "curl_command embeds the base url and bearer header" do
    command = @challenge.curl_command("https://example.com")
    assert_includes command, "curl -X POST https://example.com/api/bridge"
    assert_includes command, %(-H "Authorization: Bearer #{@challenge.token}")
  end

  test "destroyed along with its session" do
    @session.destroy
    assert_nil TemporaryApiKeyChallenge.find_by(id: @challenge.id)
  end
end
