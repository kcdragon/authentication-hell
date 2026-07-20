require "test_helper"

class SendAchievementEventJobTest < ActiveJob::TestCase
  setup { @user = users(:one) }

  CREDENTIALS = { gamestats: { api_key: "test-key", account_id: 42 } }.freeze

  test "sends an achievement event when configured" do
    occurred_at = Time.current

    calls = recording_client_calls do
      with_credentials(CREDENTIALS) do
        SendAchievementEventJob.perform_now(@user, "graduate", occurred_at)
      end
    end

    assert_equal [ { player_username: @user.username, achievement_name: "graduate", occurred_at: } ], calls
  end

  test "raises when credentials are absent" do
    recording_client_calls do
      with_credentials({}) do
        assert_raises(Gamestats::Client::Error) do
          SendAchievementEventJob.perform_now(@user, "graduate", Time.current)
        end
      end
    end
  end

  private

  def recording_client_calls
    calls = []
    original = Gamestats::Client.instance_method(:achievement_event)
    Gamestats::Client.define_method(:achievement_event) { |**kwargs| calls << kwargs }
    yield
    calls
  ensure
    Gamestats::Client.define_method(:achievement_event, original)
  end

  def with_credentials(hash)
    Rails.application.define_singleton_method(:credentials) { ActiveSupport::HashWithIndifferentAccess.new(hash) }
    yield
  ensure
    Rails.application.singleton_class.remove_method(:credentials)
  end
end
