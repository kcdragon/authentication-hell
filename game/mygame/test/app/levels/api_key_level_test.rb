require_relative "../../test_helper"

class ApiKeyLevelTest < Minitest::Test
  include GameTest

  START_URL = "http://test/games/level_api_key/start".freeze
  STATUS_URL = "http://test/games/level_api_key/status".freeze

  def setup
    @level = ApiKeyLevel.new(build_game)
    @frame = build_frame(player: Player.new, level: @level)
    @level.setup(@frame)
    DR.reset!
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
    assert_empty DR.urls, "no request before the first update"
    refute @level.bridge.extended?
  end

  def test_first_update_posts_the_start_request_once
    @level.update(@frame)
    assert_includes DR.urls, START_URL

    @level.update(@frame)
    assert_equal 1, DR.urls.count { |url| url == START_URL }, "start must only fire once"
  end

  def test_polls_status_while_waiting
    @level.update(@frame)
    assert_includes DR.urls, STATUS_URL
  end

  def test_an_opened_status_extends_the_bridge_and_stops_polling
    @level.update(@frame)
    DR.complete!(STATUS_URL, body: '{"opened":true}')
    @level.update(@frame)

    assert_operator @level.bridge.w, :>, 0

    polls_so_far = DR.urls.count { |url| url == STATUS_URL }
    100.times { @level.update(@frame) }
    assert @level.bridge.extended?
    assert_equal polls_so_far, DR.urls.count { |url| url == STATUS_URL },
                 "no need to poll once the bridge is out"
  end

  def test_completes_when_the_certificate_is_collected
    refute @level.complete?
    @level.collectables.find { |c| c.is_a?(Certificate) }.alive = false
    @level.update(@frame)
    assert @level.complete?
  end

  def test_setup_posts_guards_on_platforms_clear_of_the_chasm
    guards = @level.enemies.select { |e| e.y > GROUND_Y }

    refute_empty guards, "some hazards patrol the staircase tops"
    guards.each do |guard|
      perch = @level.platforms.select(&:holds_password)
                    .find { |p| p.y + p.h == guard.y && guard.x >= p.x && guard.x + guard.w <= p.x + p.w }
      assert perch, "guard at #{guard.x} stands on a scattered platform"
      assert_operator guard.patrol_min_x, :>=, perch.x
      assert_operator guard.patrol_max_x, :<=, perch.x + perch.w - guard.w
      refute_equal @level.bridge, perch, "the bridge is no place to stand watch"
    end
  end

  def test_enemies_spawn_on_both_sides_of_the_chasm
    near_side = @level.enemies.count { |e| e.x < ApiKeyLevel::CHASM_X }
    far_side = @level.enemies.count { |e| e.x > ApiKeyLevel::CHASM_X + ApiKeyLevel::CHASM_W }
    assert_operator near_side, :>, 0
    assert_operator far_side, :>, 0
    assert_equal @level.enemies.length, near_side + far_side
  end

  def test_render_floor_paints_the_bridge_over_the_control_bar
    @level.render_floor(@frame, 0)
    refute_empty @frame.outputs.solids, "the bridge must draw after the bar and hole cutouts to stay visible"
  end

  def test_render_floor_is_safe_before_setup
    fresh = ApiKeyLevel.new(build_game)
    frame = build_frame(player: Player.new, level: fresh)
    fresh.render_floor(frame, 0)
    assert_empty frame.outputs.solids, "the control bar draws during loading, before setup runs"
  end
end
