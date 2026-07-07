require_relative "../test_helper"

class ShellTest < Minitest::Test
  def setup
    DR.reset!
    @shell = Shell.new
  end

  def poll(start_request: nil)
    @shell.instance_variable_set(:@start_request, start_request)
    @shell.send(:poll_start_request)
  end

  def complete(code:, body:)
    { complete: true, http_response_code: code, response_data: body }
  end

  def mode = @shell.instance_variable_get(:@mode)

  def test_kicks_off_the_start_request
    poll
    assert_equal "http://test/game/start", DR.last_url
    assert_equal :loading, mode
  end

  def test_an_editor_flag_opens_the_menu
    poll(start_request: complete(code: 200, body: '{"start_level":1,"is_editor_enabled":true}'))
    assert_equal :menu, mode
  end

  def test_no_editor_flag_boots_straight_into_the_game_without_a_second_request
    poll(start_request: complete(code: 200, body: '{"start_level":2}'))

    assert_equal :game, mode
    game = @shell.instance_variable_get(:@game)
    assert_equal 2, game.level.number
    assert_empty DR.urls, "the game reuses the shell's start data — no second request"
  end

  def test_a_failed_start_still_boots_the_game_at_the_welcome_level
    poll(start_request: complete(code: 500, body: ""))

    assert_equal :game, mode
    game = @shell.instance_variable_get(:@game)
    assert_equal 0, game.level.number
  end

  def test_choosing_play_from_the_menu_starts_the_game
    poll(start_request: complete(code: 200, body: '{"start_level":1,"is_editor_enabled":true}'))
    @shell.send(:choose_play)

    assert_equal :game, mode
    game = @shell.instance_variable_get(:@game)
    assert_equal 1, game.level.number
  end

  def test_choosing_edit_from_the_menu_opens_the_editor
    poll(start_request: complete(code: 200, body: '{"start_level":0,"is_editor_enabled":true}'))
    @shell.send(:choose_edit)

    assert_equal :editor, mode
    assert_equal "http://test/editor/levels", DR.last_url, "the editor fetches its level index"
  end
end
