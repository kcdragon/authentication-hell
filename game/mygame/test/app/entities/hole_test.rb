require_relative "../../test_helper"

class HoleTest < Minitest::Test
  include GameTest

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

  def test_holes_are_wide_enough_to_swallow_the_player_but_jumpable
    jump_horizontal_reach = 320
    assert_operator Hole::W, :>, Player::WIDTH
    assert_operator Hole::W, :<, jump_horizontal_reach
  end

  def test_render_emits_solids_and_no_sprites
    hole = Hole.new(x: 1000, w: Hole::W)
    frame = build_frame
    hole.render(frame, 0)
    assert_equal 0, frame.outputs.art_sprites.length
    assert_operator frame.outputs.solids.length, :>, 0
  end

  def test_render_cuts_through_the_full_control_bar_floor
    hole = Hole.new(x: 1000, w: Hole::W)
    frame = build_frame
    hole.render(frame, 0)
    bottoms = frame.outputs.solids.map { |s| s[:y] }
    tops = frame.outputs.solids.map { |s| s[:y] + s[:h] }
    assert_equal 0, bottoms.min, "the pit reaches the bottom of the floor band"
    assert_equal GROUND_Y, tops.max, "and up to the floor line"
  end
end
