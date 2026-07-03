require_relative "../../test_helper"

# Exercises Enemy#on_collision — the enemy's own side of a contact (its fate + the
# kill count). The player's reaction lives in Player#on_collision (player_test.rb);
# here we only assert what the enemy decides about itself. The player is placed at the
# enemy's x so their bodies overlap; the vertical setup picks the outcome.
class EnemyTest < Minitest::Test
  include GameTest

  def setup
    @player = Player.new
  end

  # Feet just below the enemy's head, descending: a stomp.
  def stomp_the(enemy)
    @player.y = enemy.y + enemy.h - 6
    @player.vy = -5
    @player.grounded = false
  end

  def test_is_stompable_by_default
    assert TotpEnemy.new(x: 0, level: enemy_level).stompable?
  end

  def test_a_stomp_defeats_it
    enemy = PasswordEnemy.new(x: @player.x, level: enemy_level)
    stomp_the(enemy)
    enemy.on_collision(@player, build_args)

    refute enemy.alive
  end

  def test_a_buffering_enemy_is_spent_on_a_side_hit
    enemy = BufferingEnemy.new(x: @player.x, level: enemy_level) # feet on the ground
    enemy.on_collision(@player, build_args(tick_count: 0))
    refute enemy.alive
  end

  def test_a_side_hit_defeats_it
    enemy = TotpEnemy.new(x: @player.x, level: enemy_level) # feet on the ground, not descending
    enemy.on_collision(@player, build_args(tick_count: 0))
    refute enemy.alive
  end

  def test_survives_a_hit_while_the_player_is_invincible
    @player.hurt(build_args(tick_count: 0)) # blink window open
    enemy = TotpEnemy.new(x: @player.x, level: enemy_level)
    enemy.on_collision(@player, build_args(tick_count: 1))
    assert enemy.alive
  end

  def test_leaves_the_player_alone
    enemy = TotpEnemy.new(x: @player.x, level: enemy_level)
    enemy.on_collision(@player, build_args(tick_count: 0))
    assert_equal Player::MAX_HEARTS, @player.hearts, "the player's reaction is its own concern"
    refute @player.locked
  end

  def test_ignores_a_non_player_partner
    enemy = TotpEnemy.new(x: @player.x, level: enemy_level)
    other = TotpEnemy.new(x: @player.x, level: enemy_level) # two enemies overlapping
    enemy.on_collision(other, build_args(tick_count: 0))
    assert enemy.alive, "enemies don't collide with each other"
    assert other.alive
  end

  def test_a_defeated_enemy_drops_loot_into_its_level
    level = Level.new
    drop = HeartPickup.new(x: 0, y: GROUND_Y)
    level.define_singleton_method(:loot_for) { |_e| drop }
    enemy = TotpEnemy.new(x: @player.x, level: level)

    enemy.on_collision(@player, build_args(tick_count: 0)) # side hit → dies
    refute enemy.alive
    assert_includes level.collectables, drop
  end

  def test_a_surviving_enemy_drops_no_loot
    level = Level.new
    level.define_singleton_method(:loot_for) { |_e| flunk "no drop unless it dies" }
    @player.hurt(build_args(tick_count: 0)) # invincibility window open
    enemy = TotpEnemy.new(x: @player.x, level: level)

    enemy.on_collision(@player, build_args(tick_count: 1)) # player invincible → survives
    assert enemy.alive
    assert_empty level.collectables
  end
end
