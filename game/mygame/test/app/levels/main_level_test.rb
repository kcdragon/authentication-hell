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

  def test_setup_seeds_a_certificate_near_the_exit
    @level.setup(@args)
    certs = @args.state.collectables.select { |c| c.is_a?(Certificate) }
    assert_equal 1, certs.length
    assert_operator certs.first.x, :>, WORLD_W - 400, "certificate sits at the right exit"
  end

  def test_starts_at_the_left_edge
    assert_equal 0, @level.start_x
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

  def test_completes_when_the_certificate_is_collected_and_hands_off_to_the_gauntlet
    @level.setup(@args)
    refute @level.complete?, "shouldn't be clear before the certificate is grabbed"

    @args.state.collectables.first.alive = false # the pickup loop retired it
    @level.update(@args)

    assert @level.complete?
    assert_instance_of GauntletLevel, @level.next_level
  end

  def test_does_not_complete_while_the_certificate_is_uncollected
    @level.setup(@args)
    @args.state.player.x = 3000
    @level.update(@args)
    refute @level.complete?
  end
end
