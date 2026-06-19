require_relative "../../test_helper"

class PlatformTest < Minitest::Test
  include GameTest

  def test_scatter_builds_a_reachable_staircase_per_slot
    platforms = Platform.scatter
    # One staircase per slot, each topped by a single padlock-bearing ledge.
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
    args = build_args
    platform.render(args, 100)
    # Two solids: the ink border/underside, then the inset white face. Both are
    # camera-offset; the face sits at the ledge top (inset 3px).
    border, face = args.outputs.solids
    assert_equal 400, border[:x]                    # world x minus camera
    assert_equal 220 - Platform::UNDERSIDE_H, border[:y]
    assert_equal 403, face[:x]                       # inset 3px
    assert_equal 223, face[:y]
  end

  def test_serialize_exposes_the_rect
    data = Platform.new(x: 1, y: 2, w: 3, h: 4).serialize
    assert_equal({ x: 1, y: 2, w: 3, h: 4 }, data)
  end
end
