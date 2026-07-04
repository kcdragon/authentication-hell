require "test_helper"

class GameLevelTest < ActiveSupport::TestCase
  test "all returns GameLevels" do
    assert GameLevel.all.any?
    assert GameLevel.all.all? { |l| l.is_a?(GameLevel) }
  end

  test "find looks up by number and returns nil for an unknown level" do
    assert_equal "Welcome", GameLevel.find(0).name
    assert_nil GameLevel.find(999)
  end

  test "the levels run welcome, password, api keys, totp, then the rubyconf bonus" do
    assert_equal "Password Complexity", GameLevel.find(1).name
    assert_equal "level_1_complete", GameLevel.find(1).achievement_key
    assert_equal "API Keys", GameLevel.find(2).name
    assert_equal "Time-Based One-Time Passwords", GameLevel.find(3).name
    assert_equal "RubyConf Field Trip", GameLevel.find(4).name
    assert_nil GameLevel.find(5)
  end

  test "only the rubyconf level is a bonus" do
    assert GameLevel.find(4).bonus?
    assert_equal [ 4 ], GameLevel.all.select(&:bonus?).map(&:number)
  end

  test "graduation is the last non-bonus level" do
    assert_equal 3, GameLevel.graduation.number
  end

  test "achievement_key is derived from the level number" do
    assert_equal "level_0_complete", GameLevel.find(0).achievement_key
  end

  test "achievement carries the level's key, name, and emoji" do
    level = GameLevel.find(1)
    achievement = level.achievement

    assert_equal level.achievement_key, achievement.key
    assert_equal "#{level.name} Cleared", achievement.name
    assert_equal level.emoji, achievement.emoji
  end
end
