require "test_helper"

class AchievementTest < ActiveSupport::TestCase
  test "all returns the catalog" do
    assert_equal Achievement::SURVIVOR.size + Achievement::COMPLETION.size +
      Achievement::EVENTS.size + GameLevel.all.size,
      Achievement.all.size
    assert Achievement.all.all? { |a| a.is_a?(Achievement) }
  end

  test "all includes the event achievements" do
    %w[beta_tester rubyconf_attendee rubyconf_talk].each do |key|
      assert Achievement.find(key), "expected #{key} in the catalog"
    end
  end

  test "all includes the completion achievements" do
    %w[graduate social_sharer].each do |key|
      assert_includes Achievement.keys, key, "expected #{key} in the catalog"
    end
  end

  test "active_at awards beta_tester before RubyConf and not after it starts" do
    assert_includes active_keys("2026-07-13 23:59:00"), "beta_tester"
    assert_not_includes active_keys("2026-07-14 00:00:00"), "beta_tester"
  end

  test "active_at returns the attendee achievement only within the conference window" do
    assert_not_includes active_keys("2026-07-13 23:59:00"), "rubyconf_attendee"
    assert_includes active_keys("2026-07-15 12:00:00"), "rubyconf_attendee"
    assert_not_includes active_keys("2026-07-17 00:00:00"), "rubyconf_attendee"
  end

  test "active_at returns both attendee and talk during the talk (talk nests in conference)" do
    assert_equal %w[rubyconf_attendee rubyconf_talk], active_keys("2026-07-16 11:30:00").sort
  end

  test "active_at returns nothing well outside every window" do
    assert_empty active_keys("2026-08-01 12:00:00")
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

  private

  def active_keys(pacific_time)
    Achievement.active_at(Achievement::PACIFIC.parse(pacific_time)).map(&:key)
  end
end
