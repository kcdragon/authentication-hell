require_relative "../../test_helper"

class GauntletLevelTest < Minitest::Test
  include GameTest

  # A jump rises ~190px above its footing (19+18+…+1) and carries ~300px, so a
  # reachable next ledge is within these of the current one.
  MAX_GAP = 200
  MAX_RISE = 190

  def setup
    @level = GauntletLevel.new
    @args = build_args(player: Player.new, level: @level)
  end

  def test_number_is_three
    assert_equal 3, @level.number
  end

  def test_world_is_the_full_width
    assert_equal WORLD_W, @level.world_w
  end

  def test_melee_is_live
    assert @level.melee?
  end

  def test_setup_pulls_the_player_back_to_the_start
    @args.state.player.x = 5000 # carried over from the open world's right edge
    @args.state.camera_x = 4000
    @level.setup(@args)

    assert_equal 0, @args.state.player.x
    assert_equal 0, @args.state.camera_x
  end

  def test_setup_packs_the_floor_with_patrolling_enemies
    @level.setup(@args)

    assert_operator @args.state.enemies.length, :>=, 12, "the floor should be crawling"
    assert(@args.state.enemies.all? { |e| e.y == GROUND_Y }, "every enemy patrols the ground")
    auths = @args.state.enemies.map(&:auth).uniq
    assert_equal %i[totp passkey password].sort, auths.sort, "mixes all three auth types"
  end

  def test_setup_lays_a_continuous_reachable_platform_path
    @level.setup(@args)
    ledges = @args.state.platforms.sort_by(&:x)
    refute_empty ledges
    assert_empty @args.state.collectables

    # The first ledge is reachable from the ground and sits in the enemy-free start
    # patch (clear of the leftmost enemy's patrol) so the player can climb on safely.
    first = ledges.first
    assert_operator (first.y + first.h) - GROUND_Y, :<=, MAX_RISE
    safe_left = GauntletLevel::ENEMY_START_X - Enemy::PATROL_RANGE
    assert_operator first.x + first.w, :<=, safe_left, "first ledge clears the floor enemies"

    # Every later ledge is one hop from the previous one — no impossible gap or rise.
    ledges.each_cons(2) do |cur, nxt|
      gap = nxt.x - (cur.x + cur.w)
      rise = (nxt.y + nxt.h) - (cur.y + cur.h)
      assert_operator gap, :<=, MAX_GAP, "gap from x=#{cur.x} is too wide"
      assert_operator rise, :<=, MAX_RISE, "rise from x=#{cur.x} is too high"
    end

    # The last ledge reaches past the rightmost enemy's patrol so the drop-off lands
    # in the enemy-free end patch on the way to the wall.
    safe_right = GauntletLevel::ENEMY_END_X + Enemy::PATROL_RANGE
    assert_operator ledges.last.x + ledges.last.w, :>=, safe_right
  end

  def test_setup_cuts_pits_only_in_the_central_floor
    @level.setup(@args)
    refute_empty @args.state.holes
    @args.state.holes.each do |hole|
      # Clear of the enemy-free start patch (so the climb-on stays solid) and short of
      # the end patch / right wall (so the drop-off to the exit stays solid).
      assert_operator hole.x, :>=, GauntletLevel::ENEMY_START_X
      assert_operator hole.x + hole.w, :<=, @level.world_w - 1000
    end
  end

  def test_completes_at_the_right_wall_and_loops_a_fresh_lap
    @level.setup(@args)
    refute @level.complete?

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

  def test_draw_emits_a_caption_prompt
    @args.state.captions_on = true
    @level.draw(@args)
    refute_empty @args.outputs.labels
  end

  def test_serialize_names_the_level
    assert_equal "GauntletLevel", @level.serialize[:level]
  end
end
