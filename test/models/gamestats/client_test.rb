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
      with_deployed_version("abc1234") do
        with_credentials(CREDENTIALS) do
          Gamestats::Client.achievement_event(
            player_username: "userone", achievement_name: "graduate", occurred_at:)
        end
      end
    end

    assert_equal "/api/v1/accounts/42/achievement_events", request.path
    assert_equal "Bearer test-key", request["Authorization"]
    assert_equal "application/json", request["Content-Type"]
    assert_equal(
      { "version_name" => "abc1234", "player_username" => "userone", "achievement_name" => "graduate",
        "occurred_at" => occurred_at.iso8601 },
      JSON.parse(request.body)
    )
  end

  test "version_name carries the deployed commit and falls back to development when unset" do
    request = capture_request(Net::HTTPCreated.new("1.1", "201", "Created")) do
      with_deployed_version(nil) do
        with_credentials(CREDENTIALS) do
          Gamestats::Client.achievement_event(
            player_username: "userone", achievement_name: "graduate", occurred_at: Time.current)
        end
      end
    end

    assert_equal "development", JSON.parse(request.body)["version_name"]
  end

  test "progression_event posts the authorized JSON payload with optional fields" do
    occurred_at = Time.utc(2026, 7, 19, 12, 0, 0)

    request = capture_request(Net::HTTPCreated.new("1.1", "201", "Created")) do
      with_deployed_version("abc1234") do
        with_credentials(CREDENTIALS) do
          Gamestats::Client.progression_event(
            player_username: "userone",
            progression_type_name: "level", progression_name: "Password Complexity",
            milestone_type_name: "started", milestone_name: "started",
            is_new_instance: true, time_elapsed: 0, occurred_at:)
        end
      end
    end

    assert_equal "/api/v1/accounts/42/progression_events", request.path
    assert_equal "Bearer test-key", request["Authorization"]
    assert_equal "application/json", request["Content-Type"]
    assert_equal(
      { "version_name" => "abc1234", "player_username" => "userone",
        "progression_name" => "Password Complexity", "progression_type_name" => "level",
        "progression_milestone_name" => "started", "progression_milestone_type_name" => "started",
        "occurred_at" => occurred_at.iso8601, "is_new_instance" => true, "time_elapsed" => 0 },
      JSON.parse(request.body)
    )
  end

  test "progression_event omits is_new_instance and time_elapsed when not supplied" do
    request = capture_request(Net::HTTPCreated.new("1.1", "201", "Created")) do
      with_credentials(CREDENTIALS) do
        Gamestats::Client.progression_event(
          player_username: "userone",
          progression_type_name: "level", progression_name: "Password Complexity",
          milestone_type_name: "objective", milestone_name: "password_forged",
          occurred_at: Time.utc(2026, 7, 19, 12, 0, 0))
      end
    end

    body = JSON.parse(request.body)
    assert_not body.key?("is_new_instance")
    assert_not body.key?("time_elapsed")
    assert_equal "objective", body["progression_milestone_type_name"]
    assert_equal "password_forged", body["progression_milestone_name"]
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

  test "upload_achievement_image posts the authorized multipart form" do
    image_path = Rails.root.join("app/assets/images/achievements/totp_survivor.png")

    request = capture_request(Net::HTTPCreated.new("1.1", "201", "Created")) do
      with_credentials(CREDENTIALS) do
        Gamestats::Client.upload_achievement_image(
          achievement_name: "totp_survivor", image_path: image_path.to_s)
      end
    end

    assert_kind_of Net::HTTP::Post, request
    assert_equal "/api/v1/accounts/42/achievement_images", request.path
    assert_equal "Bearer test-key", request["Authorization"]
    assert_equal "multipart/form-data", request["Content-Type"]

    parts = request.instance_variable_get(:@body_data)
    assert_includes parts, [ "achievement_name", "totp_survivor" ]

    name, io, opts = parts.find { |part| part.first == "image" }
    assert_equal "image", name
    assert_respond_to io, :read
    assert_equal "totp_survivor.png", opts[:filename]
    assert_equal "image/png", opts[:content_type]
  end

  test "upload_achievement_image raises on a non-success response" do
    image_path = Rails.root.join("app/assets/images/achievements/totp_survivor.png")

    capture_request(Net::HTTPUnauthorized.new("1.1", "401", "Unauthorized")) do
      with_credentials(CREDENTIALS) do
        assert_raises(Gamestats::Client::Error) do
          Gamestats::Client.upload_achievement_image(
            achievement_name: "totp_survivor", image_path: image_path.to_s)
        end
      end
    end
  end

  test "upload_achievement_image raises when not configured" do
    with_credentials({}) do
      assert_raises(Gamestats::Client::Error) do
        Gamestats::Client.upload_achievement_image(
          achievement_name: "totp_survivor",
          image_path: Rails.root.join("app/assets/images/achievements/totp_survivor.png").to_s)
      end
    end
  end

  test "raises when not configured before making any request" do
    with_credentials({}) do
      assert_raises(Gamestats::Client::Error) do
        Gamestats::Client.progression_event(
          player_username: "userone",
          progression_type_name: "level", progression_name: "Password Complexity",
          milestone_type_name: "started", milestone_name: "started",
          occurred_at: Time.current)
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

  def with_deployed_version(value)
    original = ENV["KAMAL_VERSION"]
    ENV["KAMAL_VERSION"] = value
    yield
  ensure
    ENV["KAMAL_VERSION"] = original
  end
end
