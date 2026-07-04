require_relative "../test_helper"

class CaptionTest < Minitest::Test
  include GameTest

  def setup
    @args = build_args
  end

  def test_draws_a_box_and_its_copy_when_on
    Caption.new(@args, [ "Grab the padlocks", "0/4 character types" ], build_game).draw
    refute_empty @args.outputs.solids
    assert_equal 2, @args.outputs.labels.length, "one label per line"
  end

  def test_draws_nothing_when_captions_off
    Caption.new(@args, [ "Grab the padlocks" ], build_game(captions_on: false)).draw
    assert_empty @args.outputs.labels
    assert_empty @args.outputs.solids
  end

  def test_draws_nothing_for_blank_copy
    Caption.new(@args, nil, build_game).draw
    Caption.new(@args, [], build_game).draw
    assert_empty @args.outputs.labels
    assert_empty @args.outputs.solids
  end
end
