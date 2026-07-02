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

  # --- over_hole?: the pit query the player asks instead of reading holes ---

  def hole_level
    level = Level.new
    # gap spans x 200..350; seeded directly since #holes is read-only.
    level.instance_variable_set(:@holes, [ Hole.new(x: 200, w: 150) ])
    level
  end

  def test_over_hole_is_true_when_most_of_the_body_overhangs_the_gap
    player = Player.new
    player.x = 200 # fully over the gap's left side
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
end
