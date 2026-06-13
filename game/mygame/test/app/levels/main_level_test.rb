require_relative "../../test_helper"

class MainLevelTest < Minitest::Test
  include GameTest

  def setup
    @level = MainLevel.new
    @args = build_args(player: Player.new)
  end

  def test_melee_is_live
    assert @level.melee?
  end

  def test_draw_emits_a_prompt
    @level.draw(@args)
    refute_empty @args.outputs.labels
  end

  def test_serialize_names_the_level
    assert_equal "MainLevel", @level.serialize[:level]
  end
end
