require_relative "../../test_helper"

class HoleTest < Minitest::Test
  include GameTest

  # --- scatter ---

  def test_scatter_returns_the_requested_count
    assert_equal Hole::COUNT, Hole.scatter.length
    assert_equal 6, Hole.scatter(count: 6).length
  end

  def test_scatter_stays_clear_of_the_spawn_area_and_the_right_wall
    Hole.scatter(start_x: 700, end_margin: 700).each do |hole|
      assert_operator hole.x, :>=, 700
      assert_operator hole.x + hole.w, :<=, WORLD_W - 700
    end
  end

  def test_scatter_spreads_the_gaps_out_left_to_right
    xs = Hole.scatter.map(&:x)
    assert_equal xs.sort, xs, "gaps should march rightward, one per slot"
  end

  def test_scatter_respects_a_narrower_world
    Hole.scatter(world_w: 3200, start_x: 400, end_margin: 400).each do |hole|
      assert_operator hole.x + hole.w, :<=, 3200 - 400
    end
  end

  # --- geometry & rendering ---

  def test_holes_are_wide_enough_to_swallow_the_player_but_jumpable
    assert_operator Hole::W, :>, Player::WIDTH        # the player can fully clear the edge
    assert_operator Hole::W, :<, 320                  # under a jump's horizontal reach
  end

  def test_render_emits_solids_and_no_sprites
    hole = Hole.new(x: 1000, w: Hole::W)
    args = build_args
    hole.render(args, 0)
    assert_equal 0, args.outputs.sprites.length
    assert_operator args.outputs.solids.length, :>, 0
  end

  def test_render_cuts_through_the_full_control_bar_floor
    hole = Hole.new(x: 1000, w: Hole::W)
    args = build_args
    hole.render(args, 0)
    bottoms = args.outputs.solids.map { |s| s[:y] }
    tops = args.outputs.solids.map { |s| s[:y] + s[:h] }
    assert_equal 0, bottoms.min, "the pit reaches the bottom of the floor band"
    assert_equal GROUND_Y, tops.max, "and up to the floor line"
  end

  def test_serialize_shape
    assert_equal({ x: 1000, w: 150 }, Hole.new(x: 1000, w: 150).serialize)
  end
end
