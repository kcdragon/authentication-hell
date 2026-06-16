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

  def test_setup_scatters_pits_within_the_world
    @level.setup(@args)
    refute_empty @args.state.holes
    @args.state.holes.each do |hole|
      assert_operator hole.x, :>=, 0
      assert_operator hole.x + hole.w, :<=, @level.world_w
    end
  end

  def test_serialize_names_the_level
    assert_equal "MainLevel", @level.serialize[:level]
  end

  def test_number_is_two
    assert_equal 2, @level.number
  end

  def test_world_is_the_full_width
    assert_equal WORLD_W, @level.world_w
  end

  def test_completes_at_the_right_wall_and_hands_off_to_the_gauntlet
    @level.setup(@args)
    refute @level.complete?, "shouldn't be clear before reaching the wall"

    @args.state.player.x = WORLD_W - Player::WIDTH
    @level.update(@args)

    assert @level.complete?
    assert_instance_of GauntletLevel, @level.next_level
  end

  def test_does_not_complete_mid_world
    @args.state.player.x = 3000
    @level.update(@args)
    refute @level.complete?
  end
end
