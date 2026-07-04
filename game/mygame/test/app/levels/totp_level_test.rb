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

  def test_world_is_a_single_screen
    assert_equal SCREEN_W, @level.world_w
  end

  def test_allows_only_sixty_seconds
    assert_equal 60, @level.time_limit
  end

  def test_hands_off_to_the_bonus_chapter
    assert_instance_of RubyConfLevel, @level.next_level, "clearing TOTP graduates into the RubyConf bonus"
  end

  def test_setup_lays_ten_keypad_platforms_with_a_pad_on_each
    assert_equal 10, @level.platforms.length
    assert_equal 10, @level.keypad.length
    assert(@level.keypad.all? { |pad| pad.is_a?(DigitPad) })
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

  def test_setup_starts_with_no_enemies_and_a_fresh_challenge
    assert_empty @level.enemies
    lt = @level.totp
    assert lt[:active]
    refute lt[:registered]
    assert_equal 0, lt[:streak]
    assert_equal [], lt[:entered]
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

  def test_spawns_a_capped_wave_of_enemies_over_time
    register!
    @level.update(@args)
    assert_empty @level.enemies, "no enemy yet at tick 0"

    20.times do |i|
      @args.state.tick_count += TotpLevel::WAVE_INTERVAL
      @level.update(@args)
    end
    refute_empty @level.enemies
    assert_operator @level.enemies.count(&:alive), :<=, TotpLevel::WAVE_CAP
    assert(@level.enemies.all? { |e| [ TotpEnemy, PasswordEnemy, PasskeyEnemy, BufferingEnemy ].include?(e.class) })
  end

  def test_serialize_names_the_level
    assert_equal "TotpLevel", @level.serialize[:level]
  end

  private

  def register! = @level.totp[:registered] = true

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
