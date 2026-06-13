require "test_helper"

class Games::AchievementHelperTest < ActionView::TestCase
  test "achievement_toast_id is derived from the achievement key" do
    achievement = Achievement.find(:totp_survivor)
    assert_equal "achievement_toast_totp_survivor", achievement_toast_id(achievement)
  end
end
