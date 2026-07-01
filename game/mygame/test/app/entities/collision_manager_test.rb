require_relative "../../test_helper"

class CollisionManagerTest < Minitest::Test
  include GameTest

  def setup
    @manager = CollisionManager.new
    @player = Player.new
  end

  # A side hit (feet on the ground, not descending) so on_collision takes the
  # heart-loss branch, whose visible effect (a dropped heart) we can assert on.
  def side_hit_enemy
    TotpEnemy.new(x: @player.x)
  end

  # Make the player invincible so a colliding enemy *survives* the contact — the one
  # case where the colliding flag lives across ticks (a real hit retires the enemy).
  def make_invincible
    @player.hurt(build_args(tick_count: 0)) # blink runs until tick BLINK_TICKS
  end

  def test_alerts_the_enemy_on_contact
    enemy = side_hit_enemy
    @manager.resolve(build_args(player: @player, enemies: [ enemy ], tick_count: 0))
    assert enemy.colliding
    assert_equal Player::MAX_HEARTS - 1, @player.hearts
  end

  def test_edge_triggered_so_a_resting_overlap_does_not_re_hit
    make_invincible
    enemy = side_hit_enemy
    @manager.resolve(build_args(player: @player, enemies: [ enemy ], tick_count: 0))
    assert enemy.alive, "the invincible player doesn't retire it"
    assert enemy.colliding

    # Invincibility has lapsed but the bodies still overlap: no rising edge, no hit.
    @manager.resolve(build_args(player: @player, enemies: [ enemy ], tick_count: Player::BLINK_TICKS))
    assert_equal Player::MAX_HEARTS, @player.hearts
    refute @player.locked
  end

  def test_ignores_a_disjoint_enemy
    enemy = TotpEnemy.new(x: @player.x + Player::WIDTH + 200) # well clear
    @manager.resolve(build_args(player: @player, enemies: [ enemy ], tick_count: 0))
    refute enemy.colliding
    assert_equal Player::MAX_HEARTS, @player.hearts
  end

  def test_clears_the_colliding_flag_once_separated
    make_invincible
    enemy = side_hit_enemy
    @manager.resolve(build_args(player: @player, enemies: [ enemy ], tick_count: 0))
    assert enemy.colliding

    enemy.x = @player.x + Player::WIDTH + 200 # walk apart
    @manager.resolve(build_args(player: @player, enemies: [ enemy ], tick_count: 1))
    refute enemy.colliding
  end

  def test_skips_dead_enemies
    enemy = side_hit_enemy
    enemy.alive = false
    @manager.resolve(build_args(player: @player, enemies: [ enemy ], tick_count: 0))
    assert_equal Player::MAX_HEARTS, @player.hearts
    refute enemy.colliding
  end
end
