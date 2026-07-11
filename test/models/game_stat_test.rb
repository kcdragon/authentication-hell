require "test_helper"

class GameStatTest < ActiveSupport::TestCase
  setup { @user = users(:one) }

  test "recording creates a counter at one" do
    GameStat.record_reauth_totp(@user)
    assert_equal 1, @user.game_stats.find_by(key: "reauth_totp").count
  end

  test "recording increments an existing counter" do
    2.times { GameStat.record_reauth_totp(@user) }
    assert_equal 2, @user.game_stats.find_by(key: "reauth_totp").count
  end

  test "recording keeps keys independent" do
    GameStat.record_reauth_totp(@user)
    GameStat.record_defeat_totp(@user)

    assert_equal 1, @user.game_stats.find_by(key: "reauth_totp").count
    assert_equal 1, @user.game_stats.find_by(key: "defeat_totp").count
  end

  test "recording keeps users independent" do
    GameStat.record_defeat_totp(@user)
    GameStat.record_defeat_totp(users(:two))

    assert_equal 1, @user.game_stats.find_by(key: "defeat_totp").count
    assert_equal 1, users(:two).game_stats.find_by(key: "defeat_totp").count
  end

  test "record accepts a dynamically built key" do
    kind = GameStat::DEFEAT_KINDS.first
    GameStat.record(@user, "defeat_#{kind}")
    assert_equal 1, @user.game_stats.find_by(key: "defeat_#{kind}").count
  end
end
