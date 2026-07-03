require_relative "../../test_helper"

class DialogueTest < Minitest::Test
  include GameTest

  def setup
    @args = build_args
  end

  def test_draws_a_card_the_message_lines_and_a_footer
    Dialogue.new(@args, [ "Your company requires passwords", "with many kinds of characters" ], AMBER).draw
    refute_empty @args.outputs.solids
    assert_equal 3, @args.outputs.labels.length, "one per line, plus the press-E footer"
  end

  def test_draws_nothing_for_blank_copy
    Dialogue.new(@args, nil, AMBER).draw
    Dialogue.new(@args, [], AMBER).draw
    assert_empty @args.outputs.labels
    assert_empty @args.outputs.solids
  end
end
