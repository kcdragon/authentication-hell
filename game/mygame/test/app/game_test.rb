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

  def test_camera_follows_the_player_above_mid_screen
    @game.player.y = 800
    @game.player.grounded = false
    @game.send(:update_world)
    expected = @game.player.y + Player::HEIGHT / 2 - SCREEN_H / 2
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
