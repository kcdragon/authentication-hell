require "test_helper"

class AchievementsHelperTest < ActionView::TestCase
  test "renders an img when the achievement's image asset is present" do
    achievement = Achievement.find("totp_survivor")

    markup = with_image_available(true) { achievement_icon(achievement, size: 44) }

    assert_match %r{<img[^>]+achievements/totp_survivor}, markup
    assert_no_match(/#{Regexp.escape(achievement.emoji)}/, markup)
  end

  test "falls back to the emoji when no image asset is present" do
    achievement = Achievement.find("totp_survivor")

    markup = with_image_available(false) do
      achievement_icon(achievement, size: 44, classes: "grayscale opacity-40")
    end

    assert_match(/#{Regexp.escape(achievement.emoji)}/, markup)
    assert_match(/grayscale opacity-40/, markup)
    assert_no_match(/<img/, markup)
  end

  private

  def with_image_available(available)
    define_singleton_method(:achievement_image_available?) { |_achievement| available }
    yield
  end
end
