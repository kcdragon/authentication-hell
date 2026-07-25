require "test_helper"

class Gamestats::LevelProgressionTest < ActiveSupport::TestCase
  setup { @user = users(:one) }

  CREDENTIALS = { gamestats: { api_key: "test-key", account_id: 42 } }.freeze

  test "started enqueues a per-level started event" do
    calls = with_credentials(CREDENTIALS) do
      recording_enqueued { Gamestats::LevelProgression.started(@user, GameLevel.find(1)) }
    end

    assert_equal 1, calls.size
    user, attrs = calls.first
    assert_equal @user, user
    assert_equal "level", attrs[:progression_type_name]
    assert_equal "Password Complexity", attrs[:progression_name]
    assert_equal "started", attrs[:milestone_type_name]
    assert_equal "started", attrs[:milestone_name]
    assert_equal true, attrs[:is_new_instance]
    assert_equal 0, attrs[:time_elapsed]
    assert_kind_of Time, attrs[:occurred_at]
  end

  test "starting the welcome level also opens a game-wide instance" do
    calls = with_credentials(CREDENTIALS) do
      recording_enqueued { Gamestats::LevelProgression.started(@user, GameLevel.find(0)) }
    end

    assert_equal 2, calls.size
    game_event = calls.map(&:last).find { |attrs| attrs[:progression_type_name] == "game" }
    assert_equal "Authentication Hell", game_event[:progression_name]
    assert_equal "game_started", game_event[:milestone_name]
    assert_equal true, game_event[:is_new_instance]
  end

  test "objective enqueues the level's server-defined objective milestone" do
    calls = with_credentials(CREDENTIALS) do
      recording_enqueued { Gamestats::LevelProgression.objective(@user, GameLevel.find(1), 4_200) }
    end

    assert_equal 1, calls.size
    attrs = calls.first.last
    assert_equal "objective", attrs[:milestone_type_name]
    assert_equal "password_forged", attrs[:milestone_name]
    assert_equal 4_200, attrs[:time_elapsed]
  end

  test "objective enqueues nothing for a level without an objective" do
    calls = with_credentials(CREDENTIALS) do
      recording_enqueued { Gamestats::LevelProgression.objective(@user, GameLevel.find(0), 4_200) }
    end

    assert_empty calls
  end

  test "completed enqueues a per-level completed event and a game-wide milestone" do
    calls = with_credentials(CREDENTIALS) do
      recording_enqueued { Gamestats::LevelProgression.completed(@user, GameLevel.find(1), 9_000) }
    end

    assert_equal 2, calls.size
    events = calls.map(&:last)

    level_event = events.find { |attrs| attrs[:progression_type_name] == "level" }
    assert_equal "completed", level_event[:milestone_type_name]
    assert_equal "completed", level_event[:milestone_name]
    assert_equal 9_000, level_event[:time_elapsed]

    game_event = events.find { |attrs| attrs[:progression_type_name] == "game" }
    assert_equal "level_completed", game_event[:milestone_type_name]
    assert_equal "Password Complexity", game_event[:milestone_name]
    assert_equal 1, game_event[:time_elapsed]
  end

  test "enqueues nothing when gamestats is not configured" do
    calls = with_credentials({}) do
      recording_enqueued do
        Gamestats::LevelProgression.started(@user, GameLevel.find(0))
        Gamestats::LevelProgression.objective(@user, GameLevel.find(1), 1)
        Gamestats::LevelProgression.completed(@user, GameLevel.find(1), 1)
      end
    end

    assert_empty calls
  end

  private

  def recording_enqueued
    calls = []
    original = SendProgressionEventJob.method(:perform_later)
    SendProgressionEventJob.define_singleton_method(:perform_later) { |*args| calls << args }
    yield
    calls
  ensure
    SendProgressionEventJob.define_singleton_method(:perform_later, original)
  end

  def with_credentials(hash)
    Rails.application.define_singleton_method(:credentials) { ActiveSupport::HashWithIndifferentAccess.new(hash) }
    yield
  ensure
    Rails.application.singleton_class.remove_method(:credentials)
  end
end
