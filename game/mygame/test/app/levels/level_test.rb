require_relative "../../test_helper"

class LevelTest < Minitest::Test
  include GameTest

  def test_build_maps_numbers_to_their_level_classes
    assert_instance_of WelcomeLevel, Level.build(0, build_game)
    assert_instance_of PasswordLevel, Level.build(1, build_game)
    assert_instance_of ApiKeyLevel, Level.build(2, build_game)
    assert_instance_of TotpLevel, Level.build(3, build_game)
    assert_instance_of RubyConfLevel, Level.build(4, build_game)
  end

  def test_build_falls_back_to_the_welcome_level_for_an_unknown_number
    assert_instance_of WelcomeLevel, Level.build(99, build_game)
  end

  def test_build_returns_a_promoted_json_level_when_seeded
    game = build_game(extra_levels: { 5 => { "slug" => "level-9", "title" => "Level 9" } })
    level = Level.build(5, game)
    assert_instance_of JsonLevel, level
    assert_equal 5, level.number
    assert_equal "Level 9", level.title
  end

  def test_build_falls_back_to_welcome_without_promoted_data
    assert_instance_of WelcomeLevel, Level.build(5, build_game)
  end

  def test_built_levels_report_their_own_number
    [ 0, 1, 2, 3, 4 ].each { |n| assert_equal n, Level.build(n, build_game).number }
  end

  def hole_level
    level = Level.new(build_game)
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
    assert_empty Level.new(build_game).holes
    refute Level.new(build_game).over_hole?(player)
  end

  def test_rewind_gives_time_back
    level = TotpLevel.new(build_game)
    level.begin_clock(0)
    forty_seconds_in = 40 * 60
    before = level.progress(forty_seconds_in)
    level.rewind(30, forty_seconds_in)
    assert_operator level.progress(forty_seconds_in), :<, before
  end

  def test_rewind_clamps_at_the_level_start
    level = TotpLevel.new(build_game)
    level.begin_clock(0)
    ten_seconds_in = 10 * 60
    level.rewind(30, ten_seconds_in)
    assert_equal 0.0, level.progress(ten_seconds_in), "elapsed can't drop below zero"
  end

  def test_rewind_is_inert_before_the_clock_starts
    level = TotpLevel.new(build_game)
    level.rewind(30, 100)
    assert_equal 0.0, level.progress(100)
  end

  def test_wall_elapsed_counts_from_the_clock_start
    level = TotpLevel.new(build_game)
    level.begin_clock(0)
    assert_equal 300, level.wall_elapsed(300)
  end

  def test_wall_elapsed_is_zero_before_the_clock_starts
    assert_equal 0, TotpLevel.new(build_game).wall_elapsed(300)
  end

  def test_wall_elapsed_ignores_rewinds_that_shrink_elapsed
    level = TotpLevel.new(build_game)
    level.begin_clock(0)
    forty_seconds_in = 40 * 60
    before = level.elapsed(forty_seconds_in)
    level.rewind(30, forty_seconds_in)
    assert_operator level.elapsed(forty_seconds_in), :<, before
    assert_equal forty_seconds_in, level.wall_elapsed(forty_seconds_in)
  end

  def test_drop_loot_appends_the_rolled_pickup
    level = Level.new(build_game)
    drop = HeartPickup.new(x: 300, y: GROUND_Y)
    level.define_singleton_method(:loot_for) { |_e| drop }

    level.drop_loot(TotpEnemy.new(x: 300, level: level))
    assert_includes level.collectables, drop
  end

  def test_drop_loot_appends_nothing_on_an_empty_roll
    level = Level.new(build_game)
    level.define_singleton_method(:loot_for) { |_e| nil }

    level.drop_loot(TotpEnemy.new(x: 300, level: level))
    assert_empty level.collectables
  end

  def test_loot_from_a_platform_guard_lands_on_its_platform
    level = Level.new(build_game)
    platform = Platform.new(x: 500, y: 220, w: 200, h: Platform::H)
    enemy = TotpEnemy.new(x: 560, level: level).patrol_on(platform)

    drop = first_loot(level, enemy)
    assert_equal enemy.y + drop.class::LIFT, drop.y
  end

  def test_remaining_seconds_counts_down_from_the_time_limit
    level = TotpLevel.new(build_game)
    level.begin_clock(0)

    assert_equal level.time_limit, level.remaining_seconds(0)
    assert_in_delta level.time_limit - 40, level.remaining_seconds(40 * 60)
    assert_equal 0.0, level.remaining_seconds(level.time_limit * 60 + 100)
  end

  def test_remaining_seconds_recovers_after_a_rewind
    level = TotpLevel.new(build_game)
    level.begin_clock(0)
    forty_seconds_in = 40 * 60
    before = level.remaining_seconds(forty_seconds_in)

    level.rewind(30, forty_seconds_in)
    assert_in_delta before + 30, level.remaining_seconds(forty_seconds_in)
  end

  def test_note_rewind_collected_records_a_flash_at_the_pickup
    level = Level.new(build_game)
    pickup = RewindPickup.new(x: 300, y: GROUND_Y, level: level)

    level.note_rewind_collected(pickup, 500)

    assert_equal 500, level.last_rewind_at
    flash = level.rewind_flashes.fetch(0)
    assert_equal pickup.x + pickup.w / 2, flash.x
    assert_equal pickup.y + pickup.h, flash.y
    assert_equal 500, flash.started_at
  end

  def test_expire_rewind_flashes_drops_finished_ones
    level = Level.new(build_game)
    pickup = RewindPickup.new(x: 300, y: GROUND_Y, level: level)
    level.note_rewind_collected(pickup, 0)
    level.note_rewind_collected(pickup, 200)

    level.expire_rewind_flashes(REWIND_FLASH_TICKS + 10)

    assert_equal [ 200 ], level.rewind_flashes.map(&:started_at)
  end

  def test_loot_from_a_ground_enemy_still_lands_on_the_floor
    level = Level.new(build_game)
    enemy = TotpEnemy.new(x: 300, level: level)

    drop = first_loot(level, enemy)
    assert_equal GROUND_Y + drop.class::LIFT, drop.y
  end

  private

  def first_loot(level, enemy)
    200.times do
      drop = level.send(:loot_for, enemy)
      return drop if drop
    end
    flunk "the loot table never rolled a drop"
  end
end
