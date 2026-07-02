require_relative "../../test_helper"

# Exercises Enemy#on_collision — the behavior the CollisionManager fires on contact.
# The player is placed at the enemy's x so their bodies overlap; the vertical setup
# (descending onto the head vs. feet on the ground) picks the outcome. The player is
# passed as the collision partner (the manager, not args.state, supplies it).
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

  def test_stomp_defeats_the_enemy_and_bounces_the_player
    enemy = PasswordEnemy.new(x: @player.x)
    stomp_the(enemy)
    level = PasswordLevel.new # melee? is true
    enemy.on_collision(@player, build_args(level: level))

    refute enemy.alive
    assert_equal 1, level.kills
    assert_equal Player::STOMP_BOUNCE, @player.vy
    refute @player.grounded
    assert_equal Player::MAX_HEARTS, @player.hearts, "a stomp costs no heart"
  end

  def test_buffering_enemy_slows_the_player_instead_of_docking_a_heart
    enemy = BufferingEnemy.new(x: @player.x) # side hit: feet on the ground
    enemy.on_collision(@player, build_args(tick_count: 0))

    refute enemy.alive
    assert @player.slowed?(1)
    assert_equal Player::MAX_HEARTS, @player.hearts
    refute @player.locked, "buffering never re-auths"
  end

  def test_side_hit_docks_a_heart_and_locks_for_re_auth
    enemy = TotpEnemy.new(x: @player.x) # side hit: feet on the ground, not descending
    enemy.on_collision(@player, build_args(tick_count: 0))

    refute enemy.alive
    assert_equal Player::MAX_HEARTS - 1, @player.hearts
    assert @player.locked
    assert_equal :totp, @player.pending_challenge
  end

  def test_invincible_player_passes_through_unharmed
    @player.hurt(build_args(tick_count: 0)) # start the blink window
    enemy = TotpEnemy.new(x: @player.x)
    enemy.on_collision(@player, build_args(tick_count: 1))

    assert enemy.alive, "the enemy survives a hit that lands during invincibility"
    assert_equal Player::MAX_HEARTS, @player.hearts
    refute @player.locked
  end

  def test_melee_off_turns_a_would_be_stomp_into_the_re_auth
    enemy = PasswordEnemy.new(x: @player.x)
    stomp_the(enemy)
    level = WelcomeLevel.new # melee? is false until the heal
    enemy.on_collision(@player, build_args(level: level, tick_count: 0))

    assert_equal Player::MAX_HEARTS - 1, @player.hearts, "no stomp — the hit re-auths"
    assert @player.locked
    assert_equal 0, level.kills
  end

  def test_ignores_a_non_player_partner
    enemy = TotpEnemy.new(x: @player.x)
    other = TotpEnemy.new(x: @player.x) # two enemies overlapping
    enemy.on_collision(other, build_args(tick_count: 0))

    assert enemy.alive, "enemies don't collide with each other"
    assert other.alive
  end
end
