require_relative "../../test_helper"

class LevelTest < Minitest::Test
  include GameTest

  def test_build_maps_numbers_to_their_level_classes
    assert_instance_of WelcomeLevel, Level.build(0)
    assert_instance_of PasswordLevel, Level.build(1)
    assert_instance_of TotpLevel, Level.build(2)
  end

  def test_build_falls_back_to_the_welcome_level_for_an_unknown_number
    assert_instance_of WelcomeLevel, Level.build(99)
  end

  def test_built_levels_report_their_own_number
    [ 0, 1, 2 ].each { |n| assert_equal n, Level.build(n).number }
  end

  def hole_level
    level = Level.new
    level.instance_variable_set(:@holes, [ Hole.new(x: 200, w: 150) ])
    level
  end

  def test_over_hole_is_true_when_most_of_the_body_overhangs_the_gap
    player = Player.new
    player.x = 200
    assert hole_level.over_hole?(player)
  end

  def test_over_hole_is_false_when_the_gap_is_elsewhere
    player = Player.new
    player.x = 2000
    refute hole_level.over_hole?(player)
  end

  def test_over_hole_is_false_with_no_holes
    player = Player.new
    player.x = 200
    assert_empty Level.new.holes
    refute Level.new.over_hole?(player)
  end

  def test_rewind_gives_time_back
    level = TotpLevel.new
    level.begin_clock(0)
    forty_seconds_in = 40 * 60
    before = level.progress(forty_seconds_in)
    level.rewind(30, forty_seconds_in)
    assert_operator level.progress(forty_seconds_in), :<, before
  end

  def test_rewind_clamps_at_the_level_start
    level = TotpLevel.new
    level.begin_clock(0)
    ten_seconds_in = 10 * 60
    level.rewind(30, ten_seconds_in)
    assert_equal 0.0, level.progress(ten_seconds_in), "elapsed can't drop below zero"
  end

  def test_rewind_is_inert_before_the_clock_starts
    level = TotpLevel.new
    level.rewind(30, 100)
    assert_equal 0.0, level.progress(100)
  end

  def test_drop_loot_appends_the_rolled_pickup
    level = Level.new
    drop = HeartPickup.new(x: 300, y: GROUND_Y)
    level.define_singleton_method(:loot_for) { |_e| drop }

    level.drop_loot(TotpEnemy.new(x: 300, level: level))
    assert_includes level.collectables, drop
  end

  def test_drop_loot_appends_nothing_on_an_empty_roll
    level = Level.new
    level.define_singleton_method(:loot_for) { |_e| nil }

    level.drop_loot(TotpEnemy.new(x: 300, level: level))
    assert_empty level.collectables
  end
end
