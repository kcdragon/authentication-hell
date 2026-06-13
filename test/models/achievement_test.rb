require "test_helper"

class AchievementTest < ActiveSupport::TestCase
  test "all returns the catalog" do
    assert_equal Achievement::SURVIVOR.size + GameLevel.all.size, Achievement.all.size
    assert Achievement.all.all? { |a| a.is_a?(Achievement) }
  end

  test "all includes a generated achievement per level" do
    GameLevel.all.each do |level|
      assert_equal "#{level.name} Cleared", Achievement.find(level.achievement_key)&.name
    end
  end

  test "find looks up by string or symbol key" do
    assert_equal "Code Cracker", Achievement.find("totp_survivor").name
    assert_equal "Code Cracker", Achievement.find(:totp_survivor).name
  end

  test "find returns nil for an unknown key" do
    assert_nil Achievement.find("nope")
  end
end
