require_relative "../test_helper"

class ScoreTest < Minitest::Test
  include GameTest

  def test_kills_score_a_hundred_each
    result = Score.for(kills: 3, ticks: 0, hearts: 0)
    assert_equal 3, result[:kills]
    assert_equal 300, result[:kill_points]
  end

  def test_time_bonus_scales_with_the_seconds_remaining
    # 30s into a 120s limit leaves 90s → 900 bonus at 10/sec.
    result = Score.for(kills: 0, ticks: 30 * 60, hearts: 0)
    assert_equal 900, result[:time_bonus]
    assert_equal 900, result[:total]
  end

  def test_a_faster_finish_outscores_a_slower_one
    fast = Score.for(kills: 0, ticks: 20 * 60, hearts: 0)
    slow = Score.for(kills: 0, ticks: 80 * 60, hearts: 0)
    assert_operator fast[:total], :>, slow[:total]
  end

  def test_time_bonus_clamps_to_zero_at_or_past_the_limit
    at_limit = Score.for(kills: 1, ticks: LEVEL_TIME_LIMIT * 60, hearts: 0)
    past_limit = Score.for(kills: 1, ticks: LEVEL_TIME_LIMIT * 60 + 9000, hearts: 0)
    assert_equal 0, at_limit[:time_bonus]
    assert_equal 0, past_limit[:time_bonus]
    assert_equal 100, at_limit[:total]
  end

  def test_each_heart_held_at_the_exit_adds_a_bonus
    result = Score.for(kills: 0, ticks: LEVEL_TIME_LIMIT * 60, hearts: 3)
    assert_equal 3, result[:hearts]
    assert_equal 750, result[:heart_bonus]
    assert_equal 750, result[:total]
  end

  def test_more_hearts_outscore_fewer
    full = Score.for(kills: 0, ticks: 0, hearts: 3)
    hurt = Score.for(kills: 0, ticks: 0, hearts: 1)
    assert_operator full[:total], :>, hurt[:total]
  end

  def test_total_sums_kills_time_and_heart_bonuses
    result = Score.for(kills: 2, ticks: 60 * 60, hearts: 2)
    assert_equal result[:kill_points] + result[:time_bonus] + result[:heart_bonus],
                 result[:total]
  end
end
