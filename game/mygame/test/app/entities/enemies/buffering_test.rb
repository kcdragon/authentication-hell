require_relative "../../../test_helper"

class BufferingEnemyTest < Minitest::Test
  include GameTest

  def test_starts_alive_in_the_loading_grey
    enemy = BufferingEnemy.new(x: 1500)
    assert enemy.alive
    assert_equal [ MUTED[0], MUTED[1], MUTED[2] ], [ enemy.r, enemy.g, enemy.b ]
  end

  def test_slows_the_player_instead_of_re_authing
    enemy = BufferingEnemy.new(x: 1500)
    assert enemy.slows?
    assert_nil enemy.auth, "no re-auth flow — contact lags the player"
  end

  def test_other_enemies_do_not_slow
    refute TotpEnemy.new(x: 1500).slows?
  end

  def test_hitbox_is_the_full_body
    enemy = BufferingEnemy.new(x: 1500)
    assert_equal({ x: 1500, y: GROUND_Y, w: Enemy::WIDTH, h: Enemy::HEIGHT }, enemy.hitbox)
  end

  def test_patrols_within_its_region
    enemy = BufferingEnemy.new(x: 1500)
    min = enemy.patrol_min_x
    max = enemy.patrol_max_x
    200.times { enemy.update }
    assert_operator enemy.x, :>=, min
    assert_operator enemy.x, :<=, max
  end

  # --- scatter ---

  def test_scatter_returns_the_requested_count_clear_of_the_player
    spinners = BufferingEnemy.scatter(200, count: 2)
    assert_equal 2, spinners.length
    spinners.each do |s|
      assert_operator s.x, :>=, 200 + Enemy::SAFE_GAP
      assert_operator s.x + Enemy::WIDTH, :<=, WORLD_W
    end
  end

  def test_render_emits_solids_and_no_sprite
    args = build_args(tick_count: 0)
    BufferingEnemy.new(x: 1500).render(args, 100)
    assert_equal 0, args.outputs.sprites.length
    assert_equal BufferingEnemy::SEGMENTS, args.outputs.solids.length
  end
end
