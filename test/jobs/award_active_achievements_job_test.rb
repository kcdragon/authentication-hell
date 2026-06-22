require "test_helper"

class AwardActiveAchievementsJobTest < ActiveJob::TestCase
  setup { @user = users(:one) }

  test "awards the achievements active at the given time" do
    talk = Achievement::PACIFIC.parse("2026-07-16 11:30:00")

    assert_difference -> { @user.earned_achievements.count }, 2 do
      AwardActiveAchievementsJob.perform_now(@user, talk)
    end
    assert @user.earned?(:rubyconf_attendee)
    assert @user.earned?(:rubyconf_talk)
  end

  test "awards nothing outside every window" do
    outside = Achievement::PACIFIC.parse("2026-08-01 12:00:00")

    assert_no_difference -> { @user.earned_achievements.count } do
      AwardActiveAchievementsJob.perform_now(@user, outside)
    end
  end

  test "is idempotent" do
    beta = Achievement::PACIFIC.parse("2026-06-21 12:00:00")

    AwardActiveAchievementsJob.perform_now(@user, beta)
    assert_no_difference -> { @user.earned_achievements.count } do
      AwardActiveAchievementsJob.perform_now(@user, beta)
    end
  end
end
