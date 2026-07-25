require "test_helper"

class SendProgressionEventJobTest < ActiveJob::TestCase
  setup { @user = users(:one) }

  CREDENTIALS = { gamestats: { api_key: "test-key", account_id: 42 } }.freeze

  test "sends a progression event when configured" do
    occurred_at = Time.current
    attributes = {
      progression_type_name: "level", progression_name: "Password Complexity",
      milestone_type_name: "started", milestone_name: "started",
      is_new_instance: true, time_elapsed: 0, occurred_at:
    }

    calls = recording_client_calls do
      with_credentials(CREDENTIALS) do
        SendProgressionEventJob.perform_now(@user, attributes)
      end
    end

    assert_equal [ attributes.merge(player_username: @user.username) ], calls
  end

  private

  def recording_client_calls
    calls = []
    original = Gamestats::Client.instance_method(:progression_event)
    Gamestats::Client.define_method(:progression_event) { |**kwargs| calls << kwargs }
    yield
    calls
  ensure
    Gamestats::Client.define_method(:progression_event, original)
  end

  def with_credentials(hash)
    Rails.application.define_singleton_method(:credentials) { ActiveSupport::HashWithIndifferentAccess.new(hash) }
    yield
  ensure
    Rails.application.singleton_class.remove_method(:credentials)
  end
end
