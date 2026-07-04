require_relative "../../test_helper"

class ApiKeyLevelTest < Minitest::Test
  include GameTest

  def setup
    @level = ApiKeyLevel.new
    @args = build_args(player: Player.new, level: @level)
    @level.setup(@args)
    DR.last_url = nil
  end

  def test_number_is_two
    assert_equal 2, @level.number
  end

  def test_hands_off_to_the_totp_level
    assert_instance_of TotpLevel, @level.next_level
  end

  def test_allows_five_minutes_to_visit_a_terminal
    assert_equal 300, @level.time_limit
  end

  def test_the_chasm_is_far_too_wide_to_jump
    proven_jump_reach = 320
    chasm = @level.holes.max_by(&:w)
    assert_operator chasm.w, :>=, proven_jump_reach * 2
  end

  def test_the_ordinary_pits_stay_clearable
    ordinary = @level.holes.sort_by(&:w)[0..-2]
    assert_equal 2, ordinary.length
    assert(ordinary.all? { |hole| hole.w == Hole::W })
  end

  def test_no_platform_offers_a_shortcut_over_the_chasm
    chasm_zone = (ApiKeyLevel::CHASM_X - ApiKeyLevel::PLATFORM_MARGIN)..
                 (ApiKeyLevel::CHASM_X + ApiKeyLevel::CHASM_W + ApiKeyLevel::PLATFORM_MARGIN)
    overlapping = @level.platforms.reject { |p| p == @level.bridge }.select do |p|
      p.x < chasm_zone.last && p.x + p.w > chasm_zone.first
    end
    assert_empty overlapping
  end

  def test_the_bridge_spans_the_chasm_with_an_overhang_on_each_lip
    assert_equal ApiKeyLevel::CHASM_X - ApiKeyLevel::BRIDGE_OVERHANG, @level.bridge.x
    assert_includes @level.platforms, @level.bridge
    100.times { @level.bridge.open!; @level.bridge.update }
    assert_operator @level.bridge.x + @level.bridge.w, :>=,
                    ApiKeyLevel::CHASM_X + ApiKeyLevel::CHASM_W + ApiKeyLevel::BRIDGE_OVERHANG
  end

  def test_the_certificate_waits_past_the_chasm
    certificate = @level.collectables.find { |c| c.is_a?(Certificate) }
    assert certificate
    assert_operator certificate.x, :>, ApiKeyLevel::CHASM_X + ApiKeyLevel::CHASM_W
  end

  def test_setup_starts_a_fresh_challenge
    api = @level.api
    assert api[:active]
    refute api[:started]
    refute api[:opened]
  end

  def test_first_update_posts_the_start_request_once
    @level.api_next_poll = 9999
    @level.update(@args)
    assert_equal "http://test/games/level_api_key/start", DR.last_url
    assert @level.api[:started]

    DR.last_url = nil
    @level.update(@args)
    assert_nil DR.last_url, "start must only fire once"
  end

  def test_polls_status_while_waiting
    @level.update(@args)
    @level.api_start_request = nil
    @args.state.tick_count = 100
    @level.update(@args)
    assert_equal "http://test/games/level_api_key/status", DR.last_url
  end

  def test_an_opened_status_extends_the_bridge_and_stops_polling
    @level.api[:opened] = true
    @level.update(@args)

    refute @level.api[:active], "no need to poll once the bridge is out"
    assert_operator @level.bridge.w, :>, 0

    100.times { @level.update(@args) }
    assert @level.bridge.extended?
  end

  def test_completes_when_the_certificate_is_collected
    refute @level.complete?
    @level.collectables.find { |c| c.is_a?(Certificate) }.alive = false
    @level.update(@args)
    assert @level.complete?
  end

  def test_enemies_spawn_on_both_sides_of_the_chasm
    near_side = @level.enemies.count { |e| e.x < ApiKeyLevel::CHASM_X }
    far_side = @level.enemies.count { |e| e.x > ApiKeyLevel::CHASM_X + ApiKeyLevel::CHASM_W }
    assert_operator near_side, :>, 0
    assert_operator far_side, :>, 0
    assert_equal @level.enemies.length, near_side + far_side
  end

  def test_render_floor_paints_the_bridge_over_the_control_bar
    @level.render_floor(@args, 0)
    refute_empty @args.outputs.solids, "the bridge must draw after the bar and hole cutouts to stay visible"
  end

  def test_render_floor_is_safe_before_setup
    fresh = ApiKeyLevel.new
    args = build_args(player: Player.new, level: fresh)
    fresh.render_floor(args, 0)
    assert_empty args.outputs.solids, "the control bar draws during loading, before setup runs"
  end

  def test_serialize_names_the_level
    assert_equal "ApiKeyLevel", @level.serialize[:level]
  end
end
