require "test_helper"

class LevelCompletionTest < ActiveSupport::TestCase
  setup { @user = users(:one) }

  test "record creates a completion" do
    LevelCompletion.record(@user, 1, 42_000)

    completion = @user.level_completions.find_by(level_number: 1)
    assert_equal 42_000, completion.best_ms
  end

  test "a faster time lowers best_ms and bumps updated_at" do
    LevelCompletion.record(@user, 1, 42_000)
    completion = @user.level_completions.find_by(level_number: 1)
    stale = 1.hour.ago.change(usec: 0)
    completion.update_column(:updated_at, stale)

    LevelCompletion.record(@user, 1, 30_000)

    completion.reload
    assert_equal 30_000, completion.best_ms
    assert_operator completion.updated_at, :>, stale
  end

  test "a slower time changes neither best_ms nor updated_at" do
    LevelCompletion.record(@user, 1, 30_000)
    completion = @user.level_completions.find_by(level_number: 1)
    stale = 1.hour.ago.change(usec: 0)
    completion.update_column(:updated_at, stale)

    LevelCompletion.record(@user, 1, 42_000)

    completion.reload
    assert_equal 30_000, completion.best_ms
    assert_equal stale.to_i, completion.updated_at.to_i
  end

  test "record rejects zero, negative, non-integer, and over-cap times" do
    [ 0, -1, 4.2, "42000", LevelCompletion::MAX_MS + 1 ].each do |bad|
      LevelCompletion.record(@user, 1, bad)
    end

    assert_nil @user.level_completions.find_by(level_number: 1)
  end

  test "record accepts a time at the cap" do
    LevelCompletion.record(@user, 1, LevelCompletion::MAX_MS)

    assert_equal LevelCompletion::MAX_MS, @user.level_completions.find_by(level_number: 1).best_ms
  end

  test "record returns the new best on a first clear and on an improvement, nil otherwise" do
    assert_equal 42_000, LevelCompletion.record(@user, 1, 42_000), "first clear is a personal best"
    assert_equal 30_000, LevelCompletion.record(@user, 1, 30_000), "a faster time is a personal best"
    assert_nil LevelCompletion.record(@user, 1, 55_000), "a slower time is not a personal best"
    assert_nil LevelCompletion.record(@user, 1, 0), "a rejected time is never a personal best"
  end
end
