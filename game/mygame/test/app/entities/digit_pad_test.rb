require_relative "../../test_helper"

class DigitPadTest < Minitest::Test
  include GameTest

  def test_carries_its_digit_and_a_square_hitbox
    pad = DigitPad.new(x: 100, y: 250, digit: 7)
    assert_equal 7, pad.digit
    assert_equal({ x: 100, y: 250, w: DigitPad::SIZE, h: DigitPad::SIZE }, pad.hitbox)
  end

  def test_flashes_for_a_window_after_a_press
    pad = DigitPad.new(x: 0, y: 0, digit: 1)
    refute pad.flashing?(0), "no flash before a press"

    pad.press(100)
    assert pad.flashing?(100 + DigitPad::FLASH_TICKS - 1)
    refute pad.flashing?(100 + DigitPad::FLASH_TICKS)
  end

  def test_renders_two_solids_and_the_digit_label
    pad = DigitPad.new(x: 100, y: 250, digit: 4)
    frame = build_frame(tick_count: 0)
    pad.render(frame)

    assert_equal 2, frame.outputs.solids.length
    assert(frame.outputs.labels.any? { |l| l[:text] == "4" })
  end
end
