require_relative "../test_helper"

class GameBootTest < Minitest::Test
  def poll(start_request: nil)
    game = Game.new
    game.instance_variable_set(:@start_request, start_request)
    game.send(:poll_start_request)
    game
  end

  def complete(code:, body:)
    { complete: true, http_response_code: code, response_data: body }
  end

  def test_kicks_off_the_start_request_on_the_first_tick
    DR.last_url = nil
    game = poll

    assert_equal "http://test/game/start", DR.last_url
    assert_equal({ complete: false }, game.instance_variable_get(:@start_request))
    refute game.instance_variable_get(:@booted), "still in flight — the loading screen stays up"
  end

  def test_resolves_the_server_start_level_once_the_request_completes
    game = poll(start_request: complete(code: 200, body: '{"start_level":2}'))

    assert_equal 2, game.level.number
    assert game.instance_variable_get(:@booted)
    assert_nil game.instance_variable_get(:@start_request), "no handle lingers once resolved"
  end

  def test_defaults_to_the_welcome_level_when_the_response_omits_a_level
    game = poll(start_request: complete(code: 200, body: "{}"))

    assert_equal 0, game.level.number
    assert game.instance_variable_get(:@booted)
  end

  def test_defaults_to_the_welcome_level_when_the_request_fails
    game = poll(start_request: complete(code: 500, body: ""))

    assert_equal 0, game.level.number
    assert game.instance_variable_get(:@booted)
  end

  def test_a_fresh_game_wires_itself_into_its_level
    game = Game.new

    assert_equal 0, game.level.number
    assert_same game, game.level.send(:game)
    assert_equal 0, game.camera_x
    refute game.started?
    assert game.captions_on?
  end
end

class GameUnlockTest < Minitest::Test
  include GameTest

  STATUS_URL = "http://test/games/totp/status".freeze

  def setup
    DR.reset!
    @game = Game.new
    @game.instance_variable_set(:@args, build_args(player: @game.player, level: @game.level))
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
