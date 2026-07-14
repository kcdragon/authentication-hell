require_relative "../../test_helper"

class RewindPickupTest < Minitest::Test
  include GameTest

  def test_starts_alive
    assert RewindPickup.new(x: 100, y: GROUND_Y, level: TotpLevel.new(build_game)).alive?
  end

  def test_on_collision_rewinds_the_level_clock_and_retires_without_touching_hearts
    player = Player.new
    player.instance_variable_set(:@hearts, 2)
    level = TotpLevel.new(build_game)
    level.begin_clock(0)
    forty_seconds_in = 40 * 60
    frame = build_frame(player: player, level: level, tick_count: forty_seconds_in)
    before = level.progress(forty_seconds_in)

    pickup = RewindPickup.new(x: player.x, y: player.y, level: level)
    pickup.on_collision(player, frame)

    refute pickup.alive?
    assert_equal 2, player.hearts, "the rewind is a clock effect, not a heal"
    assert_operator level.progress(forty_seconds_in), :<, before
  end

  def test_a_retired_rewind_does_not_rewind_again
    player = Player.new
    level = TotpLevel.new(build_game)
    level.begin_clock(0)
    forty_seconds_in = 40 * 60
    frame = build_frame(player: player, level: level, tick_count: forty_seconds_in)

    pickup = RewindPickup.new(x: player.x, y: player.y, level: level)
    pickup.on_collision(player, frame)
    after_first = level.progress(forty_seconds_in)
    pickup.on_collision(player, frame)

    assert_equal after_first, level.progress(forty_seconds_in)
  end

  def test_on_collision_records_a_flash_for_the_collect_feedback
    player = Player.new
    level = TotpLevel.new(build_game)
    level.begin_clock(0)
    forty_seconds_in = 40 * 60
    frame = build_frame(player: player, level: level, tick_count: forty_seconds_in)

    pickup = RewindPickup.new(x: player.x, y: player.y, level: level)
    pickup.on_collision(player, frame)

    assert_equal forty_seconds_in, level.last_rewind_at
    assert_equal 1, level.rewind_flashes.length
  end

  def test_ignores_a_non_player_collider
    pickup = RewindPickup.new(x: 100, y: GROUND_Y, level: TotpLevel.new(build_game))
    pickup.on_collision(Object.new, build_frame)
    assert pickup.alive?
  end
end
