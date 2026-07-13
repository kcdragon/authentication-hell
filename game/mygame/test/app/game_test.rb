require_relative "../test_helper"

class GameBootTest < Minitest::Test
  def test_builds_the_level_through_the_injected_builder_without_http
    DR.reset!
    game = Game.new(->(g) { Level.build(2, g) })

    assert_nil DR.last_url, "no HTTP — the Shell already fetched /game/start"
    assert_equal 2, game.level.number
  end

  def test_a_fresh_game_wires_itself_into_its_level
    game = Game.new(->(g) { Level.build(0, g) })

    assert_equal 0, game.level.number
    assert_same game, game.level.send(:game)
    assert_equal 0, game.camera_x
    assert_equal 0, game.camera_y
    refute game.started?
    assert game.captions_on?
  end

  def test_drop_rates_default_to_the_level_constants
    game = Game.new(->(g) { Level.build(0, g) })

    assert_equal Level::HEART_DROP_CHANCE, game.heart_drop_chance
    assert_equal Level::REWIND_DROP_CHANCE, game.rewind_drop_chance
  end

  def test_drop_rates_come_from_the_server_when_provided
    game = Game.new(->(g) { Level.build(0, g) }, heart_drop_chance: 0.9, rewind_drop_chance: 0.05)

    assert_equal 0.9, game.heart_drop_chance
    assert_equal 0.05, game.rewind_drop_chance
  end

  def test_the_builder_also_rebuilds_the_level_on_restart
    factory_level = nil
    game = Game.new(->(g) { factory_level = JsonLevel.new(g, "slug" => "level-5") })

    assert_same factory_level, game.level
    assert_equal JsonLevel::NUMBER, game.level.number

    game.instance_variable_set(:@frame, Frame.new(nil, nil, 0))
    game.send(:restart_run)
    assert_same factory_level, game.level, "restart rebuilds through the factory"
  end
end

class GamePhaseTest < Minitest::Test
  include GameTest

  def setup
    @game = Game.new(->(g) { Level.build(0, g) })
    @game.instance_variable_set(:@frame, build_frame(player: @game.player, level: @game.level))
    @game.instance_variable_set(:@started, true)
  end

  def phase = @game.send(:phase)

  def test_the_welcome_dialogue_owns_the_opening_frame
    assert_equal :dialogue, phase
  end

  def test_intro_outranks_dialogue
    @game.level.begin_clock(0)
    assert_equal :intro, phase
  end

  def test_buffering_while_locked
    @game.player.lock!(:totp)
    assert_equal :buffering, phase
  end

  def test_paused_outranks_the_intro
    @game.instance_variable_set(:@paused, true)
    @game.level.begin_clock(0)
    assert_equal :paused, phase
  end

  def test_a_dead_player_ends_the_video_even_while_locked
    @game.player.lock!(:totp)
    @game.player.die!
    assert_equal :ended, phase
  end

  def test_beating_the_game_outranks_everything
    @game.player.die!
    @game.instance_variable_set(:@beaten, true)
    assert_equal :beaten, phase
  end
end

class GameCameraTest < Minitest::Test
  include GameTest

  def setup
    DR.reset!
    @game = Game.new(->(g) { Level.build(0, g) })
    @game.instance_variable_set(:@frame, build_frame(player: @game.player, level: @game.level))
    @game.instance_variable_set(:@started, true)
    @game.send(:setup_level)
  end

  def test_camera_stays_grounded_while_the_player_is_low
    @game.send(:update_world)
    assert_equal 0, @game.camera_y
  end

  def test_camera_follows_the_player_above_three_quarter_screen
    @game.player.y = 800
    @game.player.grounded = false
    @game.send(:update_world)
    expected = @game.player.y + Player::HEIGHT / 2 - SCREEN_H * 3 / 4
    assert_equal expected, @game.camera_y
  end

  def test_camera_clamps_at_the_world_top
    @game.player.y = WORLD_H + 100
    @game.player.grounded = false
    @game.send(:update_world)
    assert_equal WORLD_H - SCREEN_H, @game.camera_y
  end

  def test_camera_resets_on_level_setup
    @game.instance_variable_set(:@camera_y, 300)
    @game.send(:setup_level)
    assert_equal 0, @game.camera_y
  end
end

class GameSpawnTest < Minitest::Test
  include GameTest

  def setup
    DR.reset!
    @game = Game.new(->(g) { JsonLevel.new(g, "slug" => "level-5", "start_x" => 320, "start_y" => 280) })
    @game.instance_variable_set(:@frame, build_frame(player: @game.player, level: @game.level))
  end

  def test_setup_level_spawns_the_player_at_the_authored_start
    @game.send(:setup_level)
    assert_equal 320, @game.player.x
    assert_equal 280, @game.player.y
    assert @game.player.grounded
    assert_equal 0, @game.player.vy
  end
end

class GameDefeatReportTest < Minitest::Test
  include GameTest

  def setup
    DR.reset!
    @game = Game.new(->(g) { JsonLevel.new(g, "slug" => "arena") })
    @game.instance_variable_set(:@frame, build_frame(player: @game.player, level: @game.level))
    @game.send(:setup_level)
  end

  def test_a_defeated_enemy_is_reported_to_the_server
    @game.level.enemies << TotpEnemy.new(x: @game.player.x, level: @game.level)

    @game.send(:update_world)

    assert_includes DR.urls, "http://test/games/defeats?kind=totp"
  end

  def test_every_same_tick_defeat_is_reported
    @game.level.enemies << TotpEnemy.new(x: @game.player.x, level: @game.level)
    @game.level.enemies << BufferingEnemy.new(x: @game.player.x, level: @game.level)

    @game.send(:update_world)

    assert_includes DR.urls, "http://test/games/defeats?kind=totp"
    assert_includes DR.urls, "http://test/games/defeats?kind=buffering"
  end

  def test_an_uneventful_tick_reports_nothing
    @game.send(:update_world)

    refute(DR.urls.any? { |url| url.include?("/games/defeats") })
  end
end

class GameUnlockTest < Minitest::Test
  include GameTest

  STATUS_URL = "http://test/games/totp/status".freeze

  def setup
    DR.reset!
    @game = Game.new(->(g) { Level.build(0, g) })
    @game.instance_variable_set(:@frame, build_frame(player: @game.player, level: @game.level))
    @game.player.lock!(:totp)
    @game.player.confirm_lock!
  end

  def test_polls_the_challenge_status_while_locked
    @game.send(:poll_unlock)
    assert_includes DR.urls, STATUS_URL
    assert @game.player.locked, "still locked while the server has not answered"
  end

  def test_unlocks_the_player_once_the_server_clears_the_lock
    @game.send(:poll_unlock)
    DR.complete!(STATUS_URL, body: '{"locked":false}')
    @game.send(:poll_unlock)

    refute @game.player.locked
    refute @game.player.lock_confirmed
    assert_nil @game.player.pending_challenge
  end

  def test_stays_locked_while_the_server_says_so
    @game.send(:poll_unlock)
    DR.complete!(STATUS_URL, body: '{"locked":true}')
    @game.send(:poll_unlock)

    assert @game.player.locked
  end
end

class GameTimeHintTest < Minitest::Test
  include GameTest

  def setup
    DR.reset!
    @game = Game.new(->(g) { Level.build(0, g) })
    @game.instance_variable_set(:@started, true)
    @game.level.begin_clock(0)
  end

  def at_tick(tick)
    @game.instance_variable_set(:@frame, build_frame(player: @game.player,
                                                     level: @game.level, tick_count: tick))
  end

  def threshold_tick = (@game.level.time_limit - TIME_HINT_THRESHOLDS.max) * 60

  def test_the_hint_fires_when_remaining_time_reaches_the_threshold
    at_tick(threshold_tick)
    @game.send(:update_time_hint)

    assert @game.time_hint_active?
    assert_equal 0, @game.time_hint_elapsed
  end

  def test_the_hint_stays_quiet_while_time_is_plentiful
    at_tick(threshold_tick - 60)
    @game.send(:update_time_hint)

    refute @game.time_hint_active?
  end

  def test_the_hint_window_closes_after_its_run
    at_tick(threshold_tick)
    @game.send(:update_time_hint)
    at_tick(threshold_tick + TIME_HINT_TICKS)

    refute @game.time_hint_active?
  end

  def test_the_hint_does_not_restamp_while_time_stays_low
    at_tick(threshold_tick)
    @game.send(:update_time_hint)
    at_tick(threshold_tick + 120)
    @game.send(:update_time_hint)

    assert_equal 120, @game.time_hint_elapsed
  end

  def test_a_second_warning_fires_at_the_lower_threshold
    at_tick(threshold_tick)
    @game.send(:update_time_hint)
    at_tick(just_under_ten_seconds_left)
    @game.send(:update_time_hint)

    assert @game.time_hint_active?
    assert_equal 0, @game.time_hint_elapsed
  end

  def test_a_small_rewind_back_into_the_higher_band_does_not_refire
    at_tick(just_under_ten_seconds_left)
    @game.send(:update_time_hint)
    @game.level.rewind(15, just_under_ten_seconds_left)
    at_tick(just_under_ten_seconds_left + TIME_HINT_TICKS)
    @game.send(:update_time_hint)

    refute @game.time_hint_active?
  end

  def just_under_ten_seconds_left
    (@game.level.time_limit - TIME_HINT_THRESHOLDS.min) * 60 + 60
  end

  def test_the_hint_refires_when_a_rewind_buys_time_and_it_runs_low_again
    at_tick(threshold_tick)
    @game.send(:update_time_hint)
    @game.level.rewind(60, threshold_tick)
    at_tick(threshold_tick + 10)
    @game.send(:update_time_hint)
    at_tick(threshold_tick + 60 * 60 + 10)
    @game.send(:update_time_hint)

    assert @game.time_hint_active?
    assert_equal 0, @game.time_hint_elapsed
  end

  def test_the_hint_never_fires_after_game_over
    @game.player.die!
    at_tick(threshold_tick)
    @game.send(:update_time_hint)

    refute @game.time_hint_active?
  end

  def test_restart_rearms_the_hint
    at_tick(threshold_tick)
    @game.send(:update_time_hint)
    @game.send(:restart_run)

    refute @game.time_hint_active?

    @game.level.begin_clock(threshold_tick)
    at_tick(threshold_tick + threshold_tick)
    @game.send(:update_time_hint)

    assert @game.time_hint_active?
  end
end
