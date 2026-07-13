require_relative "../../test_helper"

class TimeHintTest < Minitest::Test
  include GameTest

  HintGame = Struct.new(:time_hint_elapsed)

  def test_draws_the_card_and_both_lines_at_full_strength_mid_run
    frame = build_frame
    Ui::TimeHint.new(frame, HintGame.new(TIME_HINT_TICKS / 2)).draw

    assert_equal 3, frame.outputs.solids.length
    texts = frame.outputs.labels.map { |l| l[:text] }
    assert_includes texts, "You're almost at the end of the video"
    assert_includes texts, "Defeat an enemy to rewind +0:30"
    assert(frame.outputs.labels.all? { |l| l[:a] == 255 })
  end

  def test_fades_in_from_transparent
    frame = build_frame
    Ui::TimeHint.new(frame, HintGame.new(0)).draw

    assert(frame.outputs.labels.all? { |l| l[:a] == 0 })
  end

  def test_fades_back_out_at_the_end
    frame = build_frame
    Ui::TimeHint.new(frame, HintGame.new(TIME_HINT_TICKS - 1)).draw

    assert(frame.outputs.labels.all? { |l| l[:a] < 32 })
  end
end
