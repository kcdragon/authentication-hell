require "test_helper"

class Gamestats::ClientTest < ActiveSupport::TestCase
  CREDENTIALS = { gamestats: { api_key: "test-key", account_id: 42 } }.freeze

  test "configured? is true only when api_key and account_id are present" do
    with_credentials(CREDENTIALS) { assert Gamestats::Client.configured? }
    with_credentials(gamestats: { api_key: "test-key" }) { assert_not Gamestats::Client.configured? }
    with_credentials(gamestats: { account_id: 42 }) { assert_not Gamestats::Client.configured? }
    with_credentials({}) { assert_not Gamestats::Client.configured? }
  end

  test "achievement_event posts the authorized JSON payload" do
    occurred_at = Time.utc(2026, 7, 19, 12, 0, 0)

    request = capture_request(Net::HTTPCreated.new("1.1", "201", "Created")) do
      with_credentials(CREDENTIALS) do
        Gamestats::Client.achievement_event(
          player_username: "userone", achievement_name: "graduate", occurred_at:)
      end
    end

    assert_equal "/api/v1/accounts/42/achievement_events", request.path
    assert_equal "Bearer test-key", request["Authorization"]
    assert_equal "application/json", request["Content-Type"]
    assert_equal(
      { "player_username" => "userone", "achievement_name" => "graduate",
        "occurred_at" => occurred_at.iso8601 },
      JSON.parse(request.body)
    )
  end

  test "rename_player patches the authorized JSON payload" do
    request = capture_request(Net::HTTPOK.new("1.1", "200", "OK")) do
      with_credentials(CREDENTIALS) do
        Gamestats::Client.rename_player(old_username: "userone", new_username: "usertwo")
      end
    end

    assert_kind_of Net::HTTP::Patch, request
    assert_equal "/api/v1/accounts/42/players/rename", request.path
    assert_equal "Bearer test-key", request["Authorization"]
    assert_equal "application/json", request["Content-Type"]
    assert_equal(
      { "username" => "userone", "new_username" => "usertwo" },
      JSON.parse(request.body)
    )
  end

  test "rename_player raises NotFoundError on a 404" do
    capture_request(Net::HTTPNotFound.new("1.1", "404", "Not Found")) do
      with_credentials(CREDENTIALS) do
        assert_raises(Gamestats::Client::NotFoundError) do
          Gamestats::Client.rename_player(old_username: "userone", new_username: "usertwo")
        end
      end
    end
  end

  test "raises on a non-success response" do
    capture_request(Net::HTTPUnauthorized.new("1.1", "401", "Unauthorized")) do
      with_credentials(CREDENTIALS) do
        assert_raises(Gamestats::Client::Error) do
          Gamestats::Client.achievement_event(
            player_username: "userone", achievement_name: "graduate", occurred_at: Time.current)
        end
      end
    end
  end

  private

  def capture_request(response)
    response.instance_variable_set(:@body, "")
    response.instance_variable_set(:@read, true)

    captured = nil
    fake_http = Object.new
    fake_http.define_singleton_method(:request) do |request|
      captured = request
      response
    end

    original = Net::HTTP.method(:start)
    Net::HTTP.define_singleton_method(:start) { |*_args, **_kwargs, &blk| blk.call(fake_http) }
    yield
    captured
  ensure
    Net::HTTP.define_singleton_method(:start, original)
  end

  def with_credentials(hash)
    Rails.application.define_singleton_method(:credentials) { ActiveSupport::HashWithIndifferentAccess.new(hash) }
    yield
  ensure
    Rails.application.singleton_class.remove_method(:credentials)
  end
end
