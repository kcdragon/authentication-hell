require "test_helper"

class Leaderboard::QueryTest < ActiveSupport::TestCase
  test "exposes an achievements_count aggregate" do
    users(:one).grant_achievement(:password_survivor)
    users(:one).grant_achievement(:totp_survivor)

    ranked_one = Leaderboard::Query.call.find { |u| u.id == users(:one).id }
    assert_equal 2, ranked_one.achievements_count
  end

  test "exposes auth and defeat totals without inflating achievements_count" do
    user = users(:one)
    user.grant_achievement(:password_survivor)
    user.grant_achievement(:totp_survivor)
    2.times { GameStat.record_reauth_totp(user) }
    GameStat.record_reauth_password(user)
    GameStat.record_defeat_buffering(user)

    ranked_one = Leaderboard::Query.call.find { |u| u.id == user.id }
    assert_equal 2, ranked_one.achievements_count
    assert_equal 3, ranked_one.auths_count
    assert_equal 1, ranked_one.defeats_count
  end

  test "by level orders by highest level and sorts uncleared players last" do
    users(:one).update!(highest_level_completed: 0)
    users(:two).update!(highest_level_completed: 1)

    ranked = Leaderboard::Query.call(by: :level).to_a
    assert ranked.index(users(:two)) < ranked.index(users(:one)),
      "higher level should rank higher"
    assert ranked.index(users(:one)) < ranked.index(users(:unconfirmed)),
      "a player with no cleared level sorts last"
  end

  test "by achievements orders by earned count descending" do
    users(:one).grant_achievement(:password_survivor)
    users(:one).grant_achievement(:totp_survivor)
    users(:two).grant_achievement(:password_survivor)

    ranked = Leaderboard::Query.call(by: :achievements).to_a
    assert ranked.index(users(:one)) < ranked.index(users(:two)),
      "user with more achievements should rank higher"
  end

  test "by achievements breaks count ties by who reached the count first" do
    users(:one).grant_achievement(:password_survivor)
    users(:two).grant_achievement(:totp_survivor)
    users(:one).earned_achievements.update_all(created_at: 2.days.ago)
    users(:two).earned_achievements.update_all(created_at: 1.day.ago)

    ranked = Leaderboard::Query.call(by: :achievements).to_a
    assert ranked.index(users(:one)) < ranked.index(users(:two)),
      "at an equal count, the user who reached it earlier should rank higher"
  end

  test "by auths orders by re-authentication count descending" do
    2.times { GameStat.record_reauth_totp(users(:two)) }
    GameStat.record_reauth_passkey(users(:one))

    ranked = Leaderboard::Query.call(by: :auths).to_a
    assert ranked.index(users(:two)) < ranked.index(users(:one)),
      "user with more re-auths should rank higher"
  end

  test "by defeats orders by defeat count descending" do
    2.times { GameStat.record_defeat_passkey(users(:two)) }
    GameStat.record_defeat_totp(users(:one))

    ranked = Leaderboard::Query.call(by: :defeats).to_a
    assert ranked.index(users(:two)) < ranked.index(users(:one)),
      "user with more defeats should rank higher"
  end
end
