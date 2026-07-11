require_relative "../../test_helper"

class TotpLevelTest < Minitest::Test
  include GameTest

  START_URL = "http://test/games/level_totp/start".freeze

  def setup
    DR.reset!
    @level = TotpLevel.new(build_game)
    @player = Player.new
    @frame = build_frame(player: @player, level: @level)
    @level.setup(@frame)
  end

  def test_number_is_three
    assert_equal 3, @level.number
  end

  def test_world_is_four_screens_wide
    assert_equal SCREEN_W * 4, @level.world_w
  end

  def test_allows_two_minutes
    assert_equal 120, @level.time_limit
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

  def test_pieces_spread_across_the_collection_run
    xs = pieces.map(&:x).sort
    xs.each_cons(2) do |a, b|
      assert_operator b - a, :>=, 600, "pieces bunch up: #{xs.inspect}"
    end
  end

  def test_no_piece_waits_at_the_player_spawn
    assert(pieces.all? { |piece| piece.x > @level.start_x + Player::WIDTH * 3 },
           "every piece takes a deliberate walk to reach")
  end

  def test_keypad_sits_in_the_right_hand_screen
    assert(@level.keypad.all? { |pad| pad.x >= @level.world_w - SCREEN_W })
  end

  def test_every_collection_platform_is_reachable_by_hops
    proven_jump_reach = Platform::TIERS.first - GROUND_Y
    collection = @level.platforms.reject { |plat| plat.x >= @level.world_w - SCREEN_W }
    collection.each do |plat|
      top = plat.y + plat.h
      next if top - GROUND_Y <= proven_jump_reach

      hop_from_lower_neighbor = collection.any? do |other|
        rise = top - (other.y + other.h)
        gap = [ plat.x - (other.x + other.w), other.x - (plat.x + plat.w) ].max
        !other.equal?(plat) && rise > 0 && rise <= proven_jump_reach && gap < 200
      end
      assert hop_from_lower_neighbor, "platform at x=#{plat.x} top=#{top} has no reachable hop"
    end
  end

  def test_two_jumpable_pits_guard_the_collection_run
    assert_equal TotpLevel::HOLE_XS.length, @level.holes.length
    @level.holes.each do |hole|
      assert_equal Hole::W, hole.w
      assert_operator hole.x + hole.w, :<=, @level.world_w - SCREEN_W
    end
  end

  def test_the_strip_between_the_pits_leaves_room_to_stand
    left, right = @level.holes.sort_by(&:x)
    assert_operator right.x - (left.x + left.w), :>=, Player::WIDTH * 2
  end

  def test_no_piece_hovers_over_a_pit
    pieces.each do |piece|
      @level.holes.each do |hole|
        clear = piece.x + piece.w <= hole.x || piece.x >= hole.x + hole.w
        assert clear, "piece at x=#{piece.x} hangs over the pit at x=#{hole.x}"
      end
    end
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

  def test_setup_posts_one_guard_of_each_kind_and_a_dormant_challenge
    assert_equal %w[buffering passkey password totp], @level.enemies.map(&:kind).sort
    lt = @level.totp
    refute lt.active?, "the QR only exists once its pieces are collected"
    refute lt.registered?
    assert_equal 0, lt.streak
    assert_equal [], lt.entered
  end

  def test_platform_guards_patrol_their_assigned_platforms
    TotpLevel::PLATFORM_GUARDS.each do |index, kind|
      x, top, w = TotpLevel::COLLECT_PLATFORMS[index]
      guard = @level.enemies.find { |e| e.is_a?(kind) }
      assert_equal top, guard.y
      assert_equal x, guard.patrol_min_x
      assert_equal x + w - guard.w, guard.patrol_max_x
    end
  end

  def test_ground_guards_start_clear_of_the_spawn
    TotpLevel::GROUND_GUARDS.each do |x, _kind|
      assert_operator x, :>, @level.start_x + Enemy::SAFE_GAP
    end
  end

  def test_ground_guards_never_wander_over_a_pit
    marchers = @level.enemies.select { |e| e.y == GROUND_Y }
    marchers.each do |guard|
      @level.holes.each do |hole|
        clear = guard.patrol_max_x + guard.w <= hole.x || guard.patrol_min_x >= hole.x + hole.w
        assert clear, "guard patrolling #{guard.patrol_min_x}..#{guard.patrol_max_x} crosses the pit at x=#{hole.x}"
      end
    end
  end

  def test_totp_stays_dormant_while_pieces_remain
    @level.update(@frame)

    refute @level.totp.active?
    refute @level.totp.started?
    refute_includes DR.urls, START_URL, "no start call before the QR is assembled"
  end

  def test_collecting_every_piece_activates_the_totp_challenge
    collect_pieces!
    @level.update(@frame)

    lt = @level.totp
    assert lt.active?
    assert lt.started?
    assert_includes DR.urls, START_URL, "assembling the QR fires the start call"
  end

  def test_completion_does_not_rearm_the_challenge
    register!
    @level.totp.record_status("complete" => true)
    2.times { @level.update(@frame) }

    refute @level.totp.active?
  end

  def test_keypad_is_inert_until_the_authenticator_is_registered
    press(pad_for(5))
    assert_empty @level.totp.entered
  end

  def test_standing_on_a_key_without_pressing_e_enters_nothing
    register!
    pad = pad_for(5)
    stand_on(pad)
    @level.update(@frame)

    assert_empty @level.totp.entered, "navigation must never type a digit"
  end

  def test_pressing_e_punches_in_the_key_underfoot
    register!
    press(pad_for(7))
    assert_equal [ 7 ], @level.totp.entered
  end

  def test_six_digits_assemble_a_pending_code_and_clear_the_tray
    register!
    [ 1, 2, 3, 4, 5, 6 ].each { |d| press(pad_for(d)) }

    lt = @level.totp
    assert_equal "123456", lt.pending_code
    assert_equal [], lt.entered
    assert lt.submitting?, "entry freezes until the server answers the submit"
  end

  def test_completes_once_the_server_reports_the_streak_met
    register!
    @level.totp.record_status("complete" => true)
    @level.update(@frame)

    assert @level.complete?
    refute @level.totp.active?, "stops polling once cleared"
  end

  def test_hud_hides_the_keypad_chrome_until_registered
    @level.draw_hud(@frame)
    assert_empty @frame.outputs.solids

    register!
    @level.draw_hud(@frame)
    refute_empty @frame.outputs.solids
  end

  def test_draw_captions_the_piece_tally
    @level.draw(@frame)

    tally = "0/#{TotpLevel::QR_PIECE_COUNT} QR code pieces"
    assert(@frame.outputs.labels.any? { |label| label[:text] == tally })
  end

  def test_draw_prompts_the_scan_once_assembled
    collect_pieces!
    @level.draw(@frame)

    assert(@frame.outputs.labels.any? { |label| label[:text].include?("scan") })
  end

  def test_draw_goes_quiet_once_registered
    register!
    @level.draw(@frame)

    assert_empty @frame.outputs.labels
  end

  def test_waves_spawn_during_the_collection_phase
    @level.update(@frame)
    baseline = @level.enemies.length

    @frame = build_frame(player: @player, level: @level, tick_count: WaveSpawner::INTERVAL)
    @level.update(@frame)
    assert_equal baseline + 1, @level.enemies.length, "waves harass the hunt before any registration"
  end


  private

  def pieces = @level.collectables.select { |c| c.is_a?(QrPiece) }

  def collect_pieces! = pieces.each { |piece| piece.alive = false }

  def register!
    collect_pieces!
    @level.update(@frame)
    @level.totp.record_status("registered" => true)
  end

  def pad_for(digit) = @level.keypad.find { |pad| pad.digit == digit }

  def stand_on(pad)
    @player.x = pad.x
    @player.y = pad.y
  end

  def press(pad)
    stand_on(pad)
    @frame.inputs.keyboard.key_down.e = true
    @level.update(@frame)
    @frame.inputs.keyboard.key_down.e = false
  end
end
