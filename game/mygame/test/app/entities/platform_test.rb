require_relative "../../test_helper"

class PlatformTest < Minitest::Test
  include GameTest

  def test_scatter_builds_a_reachable_staircase_per_slot
    platforms = Platform.scatter
    assert_equal Platform::COUNT, platforms.count(&:holds_password)
    platforms.each do |plat|
      assert_includes Platform::TIERS, plat.y + plat.h
      assert_equal Platform::H, plat.h
      assert_operator plat.x, :>=, 0
      assert_operator plat.x + plat.w, :<=, WORLD_W
    end
  end

  def test_scatter_count_sets_the_number_of_staircases
    assert_equal 3, Platform.scatter(count: 3).count(&:holds_password)
  end

  def test_render_emits_camera_offset_solids
    platform = Platform.new(x: 500, y: 220, w: 200, h: 30)
    frame = build_frame
    platform.render(frame, 100)
    border, face = frame.outputs.solids
    assert_equal 400, border[:x]
    assert_equal 220 - Platform::UNDERSIDE_H, border[:y]
    assert_equal 403, face[:x]
    assert_equal 223, face[:y]
  end
end
