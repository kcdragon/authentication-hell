require_relative "../../test_helper"

class PlatformTest < Minitest::Test
  include GameTest

  def test_scatter_builds_one_ledge_per_slot_at_a_reachable_tier
    platforms = Platform.scatter
    assert_equal Platform::COUNT, platforms.length
    platforms.each do |plat|
      assert_includes Platform::TIERS, plat.y + plat.h
      assert_equal Platform::H, plat.h
      assert_operator plat.x, :>=, 0
      assert_operator plat.x + plat.w, :<=, WORLD_W
    end
  end

  def test_scatter_count_is_overridable
    assert_equal 3, Platform.scatter(count: 3).length
  end

  def test_render_emits_a_camera_offset_solid
    platform = Platform.new(x: 500, y: 220, w: 200, h: 30)
    args = build_args
    platform.render(args, 100)
    solid = args.outputs.solids.first
    assert_equal 400, solid[:x] # world x minus camera
    assert_equal 220, solid[:y]
  end

  def test_serialize_exposes_the_rect
    data = Platform.new(x: 1, y: 2, w: 3, h: 4).serialize
    assert_equal({ x: 1, y: 2, w: 3, h: 4 }, data)
  end
end
