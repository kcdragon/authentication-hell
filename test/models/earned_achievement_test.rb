require "test_helper"

class EarnedAchievementTest < ActiveSupport::TestCase
  setup { @user = users(:one) }

  test "grant_achievement records the achievement once" do
    assert_difference -> { @user.earned_achievements.count }, 1 do
      assert @user.grant_achievement(:totp_survivor)
    end

    assert @user.earned?(:totp_survivor)
    assert_includes @user.earned_achievement_keys, "totp_survivor"
  end

  test "grant_achievement is a no-op the second time" do
    @user.grant_achievement(:totp_survivor)

    assert_no_difference -> { @user.earned_achievements.count } do
      assert_nil @user.grant_achievement(:totp_survivor)
    end
  end

  test "rejects an achievement_key outside the catalog" do
    earned = @user.earned_achievements.build(achievement_key: "not_real")
    assert_not earned.valid?
    assert earned.errors[:achievement_key].any?
  end

  test "grant_achievement is a no-op for an unknown key" do
    assert_no_difference -> { @user.earned_achievements.count } do
      assert_nil @user.grant_achievement(:nope)
    end
  end

  test "earned? is false for an ungranted achievement" do
    assert_not @user.earned?(:passkey_survivor)
  end

  test "achievement maps back to the catalog entry" do
    earned = @user.earned_achievements.create!(achievement_key: "passkey_survivor")
    assert_equal "Key Master", earned.achievement.name
  end

  test "the same key may be earned by different users" do
    @user.grant_achievement(:totp_survivor)
    assert users(:two).grant_achievement(:totp_survivor)
  end
end
