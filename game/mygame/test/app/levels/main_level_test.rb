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

  def test_setup_seeds_enemies_and_platforms
    @level.setup(@args)
    assert_equal 6, @args.state.enemies.length
    assert_equal Platform::COUNT, @args.state.platforms.length
  end

  def test_enemies_never_spawn_on_top_of_a_carried_over_player
    @args.state.player.x = 1200 # as if the player roamed right during the tutorial
    @level.setup(@args)
    nearest_reach = @args.state.enemies.map { |e| e.x - Enemy::PATROL_RANGE }.min
    assert nearest_reach > @args.state.player.x + Player::WIDTH,
           "nearest enemy patrol reach (#{nearest_reach}) must clear the player's right edge"
  end

  def test_draw_emits_a_prompt
    @level.draw(@args)
    refute_empty @args.outputs.labels
  end

  def test_serialize_names_the_level
    assert_equal "MainLevel", @level.serialize[:level]
  end

  def test_number_is_one
    assert_equal 1, @level.number
  end
end
