require_relative "../../test_helper"

class RewindPickupTest < Minitest::Test
  include GameTest

  def test_starts_alive
    assert RewindPickup.new(x: 100, y: GROUND_Y, level: TotpLevel.new).alive?
  end

  def test_on_collision_rewinds_the_level_clock_and_retires_without_touching_hearts
    player = Player.new
    player.hearts = 2
    level = TotpLevel.new
    level.begin_clock(0)
    forty_seconds_in = 40 * 60
    args = build_args(player: player, level: level, tick_count: forty_seconds_in)
    before = level.progress(forty_seconds_in)

    pickup = RewindPickup.new(x: player.x, y: player.y, level: level)
    pickup.on_collision(player, args)

    refute pickup.alive?
    assert_equal 2, player.hearts, "the rewind is a clock effect, not a heal"
    assert_operator level.progress(forty_seconds_in), :<, before
  end

  def test_a_retired_rewind_does_not_rewind_again
    player = Player.new
    level = TotpLevel.new
    level.begin_clock(0)
    forty_seconds_in = 40 * 60
    args = build_args(player: player, level: level, tick_count: forty_seconds_in)

    pickup = RewindPickup.new(x: player.x, y: player.y, level: level)
    pickup.on_collision(player, args)
    after_first = level.progress(forty_seconds_in)
    pickup.on_collision(player, args)

    assert_equal after_first, level.progress(forty_seconds_in)
  end

  def test_ignores_a_non_player_collider
    pickup = RewindPickup.new(x: 100, y: GROUND_Y, level: TotpLevel.new)
    pickup.on_collision(Object.new, build_args)
    assert pickup.alive?
  end

  def test_serialize_describes_the_pickup
    data = RewindPickup.new(x: 100, y: GROUND_Y, level: TotpLevel.new).serialize
    assert_equal 100, data[:x]
    assert_equal true, data[:alive]
  end
end
