require_relative "../test_helper"

class HintCardTest < Minitest::Test
  include GameTest

  def setup
    @args = build_args
  end

  def test_show_draws_a_card_and_its_copy_at_full_opacity
    HintCard.new(@args, [ "Grab the padlocks", "0/4 character types" ]).show
    refute_empty @args.outputs.solids
    refute_empty @args.outputs.labels
    assert_equal 255, @args.outputs.labels.first[:a] # just appeared
  end

  def test_show_draws_nothing_for_blank_copy
    HintCard.new(@args, nil).show
    HintCard.new(@args, []).show
    assert_empty @args.outputs.labels
    assert_empty @args.outputs.solids
  end

  def test_holds_full_opacity_then_fades_to_nothing
    lines = [ "Hop the platforms" ]
    HintCard.new(@args, lines).show # starts the timer at tick 0
    assert_equal 255, @args.outputs.labels.first[:a]

    show_again_at(HintCard::HOLD_TICKS, lines)
    assert_equal 255, @args.outputs.labels.first[:a] # still within the hold

    show_again_at(HintCard::HOLD_TICKS + HintCard::FADE_TICKS, lines)
    assert_empty @args.outputs.labels # fully faded — nothing drawn
  end

  def test_changing_the_copy_re_shows_the_card
    HintCard.new(@args, [ "0/4 character types" ]).show # tick 0

    show_again_at(HintCard::HOLD_TICKS + HintCard::FADE_TICKS, [ "0/4 character types" ])
    assert_empty @args.outputs.labels # faded out

    HintCard.new(@args, [ "1/4 character types" ]).show # new copy resets the timer
    refute_empty @args.outputs.labels
    assert_equal 255, @args.outputs.labels.first[:a]
  end

  private

  # Re-run show on a fresh frame at the given tick, so each assertion sees only that
  # frame's draws.
  def show_again_at(tick, lines)
    @args.outputs = Outputs.new([], [], [])
    @args.state.tick_count = tick
    HintCard.new(@args, lines).show
  end
end
