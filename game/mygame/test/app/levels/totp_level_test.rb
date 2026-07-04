require_relative "../../test_helper"

class TotpLevelTest < Minitest::Test
  include GameTest

  def setup
    @level = TotpLevel.new
    @args = build_args(player: Player.new, level: @level)
    @level.setup(@args)
  end

  def test_number_is_three
    assert_equal 3, @level.number
  end

  def test_world_is_two_screens_wide
    assert_equal SCREEN_W * 2, @level.world_w
  end

  def test_allows_only_sixty_seconds
    assert_equal 60, @level.time_limit
  end

  def test_hands_off_to_the_bonus_chapter
    assert_instance_of RubyConfLevel, @level.next_level, "clearing TOTP graduates into the RubyConf bonus"
  end

  def test_setup_lays_ten_keypad_platforms_with_a_pad_on_each
    assert_equal 10 + TotpLevel::COLLECT_PLATFORMS.length, @level.platforms.length
    assert_equal 10, @level.keypad.length
    assert(@level.keypad.all? { |pad| pad.is_a?(DigitPad) })
  end

  def test_setup_scatters_four_qr_pieces
    assert_equal TotpLevel::QR_PIECE_COUNT, pieces.length
    assert_equal (0...TotpLevel::QR_PIECE_COUNT).to_a, pieces.map(&:index).sort
  end

  def test_pieces_all_sit_in_the_collection_screen
    assert(pieces.all? { |piece| piece.x + piece.w <= @level.world_w - SCREEN_W })
  end

  def test_no_piece_waits_at_the_player_spawn
    assert(pieces.all? { |piece| piece.x > @level.start_x + Player::WIDTH * 3 },
           "every piece takes a deliberate walk to reach")
  end

  def test_keypad_sits_in_the_right_hand_screen
    assert(@level.keypad.all? { |pad| pad.x >= @level.world_w - SCREEN_W })
  end

  def test_collection_platforms_are_one_hop_up
    proven_jump_reach = Platform::TIERS.first - GROUND_Y
    collection = @level.platforms.reject { |plat| plat.x >= @level.world_w - SCREEN_W }
    assert(collection.all? { |plat| plat.y + plat.h - GROUND_Y <= proven_jump_reach })
  end

  def test_setup_places_every_digit_zero_through_nine
    assert_equal (0..9).to_a, @level.keypad.map(&:digit).sort
  end

  def test_keys_are_laid_out_like_a_phone_number_pad
    at = @level.keypad.to_h { |pad| [ pad.digit, [ pad.x, pad.y ] ] }
    assert_equal at[1][1], at[2][1], "1-2-3 share a row"
    assert_equal at[2][1], at[3][1]
    assert_operator at[1][0], :<, at[2][0]
    assert_operator at[2][0], :<, at[3][0]
    assert_operator at[7][1], :>, at[4][1], "7-8-9 sit above 4-5-6"
    assert_operator at[4][1], :>, at[1][1], "4-5-6 sit above 1-2-3"
    assert_equal at[2][0], at[0][0], "0 is in the middle column"
    assert_operator at[0][1], :<, at[1][1], "0 is the lowest key"
  end

  def test_rows_are_within_a_single_hop_of_each_other
    proven_jump_reach = Platform::TIERS.first - GROUND_Y
    tops = (@level.keypad.map(&:y) + [ GROUND_Y ]).uniq.sort
    steps = tops.each_cons(2).map { |a, b| b - a }
    assert(steps.all? { |s| s <= proven_jump_reach }, "each row is a reachable hop above the last: #{steps.inspect}")
  end

  def test_setup_starts_with_no_enemies_and_a_dormant_challenge
    assert_empty @level.enemies
    lt = @level.totp
    refute lt[:active], "the QR only exists once its pieces are collected"
    refute lt[:registered]
    assert_equal 0, lt[:streak]
    assert_equal [], lt[:entered]
  end

  def test_totp_stays_dormant_while_pieces_remain
    @level.update(@args)

    refute @level.totp[:active]
    refute @level.totp[:started]
    assert_nil @level.totp_start_request, "no start call before the QR is assembled"
  end

  def test_collecting_every_piece_activates_the_totp_challenge
    collect_pieces!
    @level.update(@args)

    lt = @level.totp
    assert lt[:active]
    assert lt[:started]
    refute_nil @level.totp_start_request, "assembling the QR fires the start call"
  end

  def test_completion_does_not_rearm_the_challenge
    register!
    @level.totp[:complete] = true
    2.times { @level.update(@args) }

    refute @level.totp[:active]
  end

  def test_keypad_is_inert_until_the_authenticator_is_registered
    press(pad_for(5))
    assert_empty @level.totp[:entered]
  end

  def test_standing_on_a_key_without_pressing_e_enters_nothing
    register!
    pad = pad_for(5)
    stand_on(pad)
    @level.update(@args)

    assert_empty @level.totp[:entered], "navigation must never type a digit"
  end

  def test_pressing_e_punches_in_the_key_underfoot
    register!
    press(pad_for(7))
    assert_equal [ 7 ], @level.totp[:entered]
  end

  def test_six_digits_assemble_a_pending_code_and_clear_the_tray
    register!
    [ 1, 2, 3, 4, 5, 6 ].each { |d| press(pad_for(d)) }

    lt = @level.totp
    assert_equal "123456", lt[:pending_code]
    assert_equal [], lt[:entered]
    assert lt[:submitting], "entry freezes until the server answers the submit"
  end

  def test_completes_once_the_server_reports_the_streak_met
    register!
    @level.totp[:complete] = true
    @level.update(@args)

    assert @level.complete?
    refute @level.totp[:active], "stops polling once cleared"
  end

  def test_hud_hides_the_keypad_chrome_until_registered
    @level.draw_hud(@args)
    assert_empty @args.outputs.solids

    register!
    @level.draw_hud(@args)
    refute_empty @args.outputs.solids
  end

  def test_draw_captions_the_piece_tally
    @level.draw(@args)

    tally = "0/#{TotpLevel::QR_PIECE_COUNT} QR code pieces"
    assert(@args.outputs.labels.any? { |label| label[:text] == tally })
  end

  def test_draw_prompts_the_scan_once_assembled
    collect_pieces!
    @level.draw(@args)

    assert(@args.outputs.labels.any? { |label| label[:text].include?("scan") })
  end

  def test_draw_goes_quiet_once_registered
    register!
    @level.draw(@args)

    assert_empty @args.outputs.labels
  end

  def test_waves_spawn_during_the_collection_phase
    @level.update(@args)
    assert_empty @level.enemies, "no enemy yet at tick 0"

    @args.state.tick_count += WaveSpawner::INTERVAL
    @level.update(@args)
    refute_empty @level.enemies, "enemies harass the hunt before any registration"
  end

  def test_serialize_names_the_level
    assert_equal "TotpLevel", @level.serialize[:level]
  end

  private

  def pieces = @level.collectables.select { |c| c.is_a?(QrPiece) }

  def collect_pieces! = pieces.each { |piece| piece.alive = false }

  def register!
    collect_pieces!
    @level.update(@args)
    @level.totp[:registered] = true
  end

  def pad_for(digit) = @level.keypad.find { |pad| pad.digit == digit }

  def stand_on(pad)
    @args.state.player.x = pad.x
    @args.state.player.y = pad.y
  end

  def press(pad)
    stand_on(pad)
    @args.inputs.keyboard.key_down.e = true
    @level.update(@args)
    @args.inputs.keyboard.key_down.e = false
  end
end
