require_relative "../../../test_helper"

class BufferingEnemyTest < Minitest::Test
  include GameTest

  def test_starts_alive_in_the_loading_grey
    enemy = BufferingEnemy.new(x: 1500, level: enemy_level)
    assert enemy.alive
    color = %i[@r @g @b].map { |ivar| enemy.instance_variable_get(ivar) }
    assert_equal [ MUTED[0], MUTED[1], MUTED[2] ], color
  end

  def test_slows_the_player_instead_of_re_authing
    enemy = BufferingEnemy.new(x: 1500, level: enemy_level)
    assert enemy.slows?
    assert_nil enemy.auth, "no re-auth flow — contact lags the player"
  end

  def test_other_enemies_do_not_slow
    refute TotpEnemy.new(x: 1500, level: enemy_level).slows?
  end

  def test_hitbox_is_the_full_body
    enemy = BufferingEnemy.new(x: 1500, level: enemy_level)
    assert_equal({ x: 1500, y: GROUND_Y, w: Enemy::WIDTH, h: Enemy::HEIGHT }, enemy.hitbox)
  end

  def test_patrols_within_its_region
    enemy = BufferingEnemy.new(x: 1500, level: enemy_level)
    min = enemy.patrol_min_x
    max = enemy.patrol_max_x
    200.times { enemy.update }
    assert_operator enemy.x, :>=, min
    assert_operator enemy.x, :<=, max
  end

  def test_render_emits_solids_and_no_sprite
    frame = build_frame(tick_count: 0)
    BufferingEnemy.new(x: 1500, level: enemy_level).render(frame, 100)
    assert_equal 0, frame.outputs.sprites.length
    assert_equal BufferingEnemy::SEGMENTS, frame.outputs.solids.length
  end
end
