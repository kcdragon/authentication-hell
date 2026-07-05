require_relative "../../test_helper"

class DialogueTest < Minitest::Test
  include GameTest

  def setup
    @frame = build_frame
  end

  def test_draws_a_card_the_message_lines_and_a_footer
    Dialogue.new(@frame, [ "Your company requires passwords", "with many kinds of characters" ], AMBER).draw
    refute_empty @frame.outputs.solids
    assert_equal 3, @frame.outputs.labels.length, "one per line, plus the press-E footer"
  end

  def test_draws_nothing_for_blank_copy
    Dialogue.new(@frame, nil, AMBER).draw
    Dialogue.new(@frame, [], AMBER).draw
    assert_empty @frame.outputs.labels
    assert_empty @frame.outputs.solids
  end
end
