require "test_helper"

class Gamestats::RenamePlayerJobTest < ActiveJob::TestCase
  CREDENTIALS = { gamestats: { api_key: "test-key", account_id: 42 } }.freeze

  test "renames the player when configured" do
    calls = recording_client_calls do
      with_credentials(CREDENTIALS) do
        Gamestats::RenamePlayerJob.perform_now("userone", "usertwo")
      end
    end

    assert_equal [ { old_username: "userone", new_username: "usertwo" } ], calls
  end

  test "propagates a NotFoundError" do
    with_credentials(CREDENTIALS) do
      original = Gamestats::Client.instance_method(:rename_player)
      Gamestats::Client.define_method(:rename_player) { |**| raise Gamestats::Client::NotFoundError }
      assert_raises(Gamestats::Client::NotFoundError) { Gamestats::RenamePlayerJob.perform_now("userone", "usertwo") }
    ensure
      Gamestats::Client.define_method(:rename_player, original)
    end
  end

  test "raises when credentials are absent" do
    recording_client_calls do
      with_credentials({}) do
        assert_raises(Gamestats::Client::Error) do
          Gamestats::RenamePlayerJob.perform_now("userone", "usertwo")
        end
      end
    end
  end

  private

  def recording_client_calls
    calls = []
    original = Gamestats::Client.instance_method(:rename_player)
    Gamestats::Client.define_method(:rename_player) { |**kwargs| calls << kwargs }
    yield
    calls
  ensure
    Gamestats::Client.define_method(:rename_player, original)
  end

  def with_credentials(hash)
    Rails.application.define_singleton_method(:credentials) { ActiveSupport::HashWithIndifferentAccess.new(hash) }
    yield
  ensure
    Rails.application.singleton_class.remove_method(:credentials)
  end
end
