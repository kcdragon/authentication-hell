require_relative "../../test_helper"

class TutorialLevelTest < Minitest::Test
  include GameTest

  def setup
    @level = TutorialLevel.new
    @args = build_args(player: Player.new)
  end

  def test_melee_is_off
    refute @level.melee?
  end

  def test_setup_seeds_one_stationary_password_enemy_and_no_platforms
    @level.setup(@args)
    assert_equal 1, @args.state.enemies.length
    enemy = @args.state.enemies.first
    assert_equal :password, enemy.auth
    assert_equal 0, enemy.vx
    assert_empty @args.state.platforms
  end

  def test_draw_emits_a_prompt
    @level.draw(@args)
    refute_empty @args.outputs.labels
  end

  def test_serialize_names_the_level
    assert_equal "TutorialLevel", @level.serialize[:level]
  end

  def test_number_is_zero
    assert_equal 0, @level.number
  end
end
