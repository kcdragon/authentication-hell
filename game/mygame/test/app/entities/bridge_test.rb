require_relative "../../test_helper"

class BridgeTest < Minitest::Test
  include GameTest

  def setup
    @bridge = Bridge.new(x: 3360, span: 720)
  end

  def test_starts_retracted_and_flush_with_the_ground
    assert_equal 0, @bridge.w
    assert_equal GROUND_Y, @bridge.y + @bridge.h, "the walkable top must sit at ground level"
    refute @bridge.extended?
  end

  def test_never_carries_password_characters
    refute @bridge.holds_password
  end

  def test_update_does_nothing_until_opened
    5.times { @bridge.update }
    assert_equal 0, @bridge.w
  end

  def test_extends_in_steps_once_opened_and_clamps_at_the_span
    @bridge.open!
    @bridge.update
    assert_equal Bridge::EXTEND_SPEED, @bridge.w

    100.times { @bridge.update }
    assert_equal 720, @bridge.w
    assert @bridge.extended?
  end

  def test_render_marks_the_anchor_stub_while_retracted
    args = build_args
    @bridge.render(args)
    assert_equal 1, args.outputs.solids.length
  end

  def test_render_draws_the_deck_once_extending
    args = build_args
    @bridge.open!
    @bridge.update
    @bridge.render(args)
    assert_equal 3, args.outputs.solids.length, "stub, ink body, and teal deck"
  end
end
