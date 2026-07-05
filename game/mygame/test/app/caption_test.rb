require_relative "../test_helper"

class CaptionTest < Minitest::Test
  include GameTest

  def setup
    @frame = build_frame
  end

  def test_draws_a_box_and_its_copy_when_on
    Caption.new(@frame, [ "Grab the padlocks", "0/4 character types" ], build_game).draw
    refute_empty @frame.outputs.solids
    assert_equal 2, @frame.outputs.labels.length, "one label per line"
  end

  def test_draws_nothing_when_captions_off
    Caption.new(@frame, [ "Grab the padlocks" ], build_game(captions_on: false)).draw
    assert_empty @frame.outputs.labels
    assert_empty @frame.outputs.solids
  end

  def test_draws_nothing_for_blank_copy
    Caption.new(@frame, nil, build_game).draw
    Caption.new(@frame, [], build_game).draw
    assert_empty @frame.outputs.labels
    assert_empty @frame.outputs.solids
  end
end
