require_relative "../../../test_helper"

# The tutorial gate always forces the re-auth — you can't stomp past it — unlike an
# ordinary enemy.
class TutorialEnemyTest < Minitest::Test
  include GameTest

  def setup
    @player = Player.new
    @enemy = TutorialEnemy.new(x: @player.x)
  end

  def test_looks_and_authenticates_like_a_password_enemy
    assert_kind_of PasswordEnemy, @enemy
    assert_equal :password, @enemy.auth
  end

  def test_a_stomp_still_forces_the_re_auth_instead_of_defeating_it
    @player.y = @enemy.y + @enemy.h - 6 # feet on its head, descending
    @player.vy = -5
    @player.grounded = false
    @enemy.on_collision(@player, build_args(tick_count: 0))

    refute @enemy.alive
    assert_equal Player::MAX_HEARTS - 1, @player.hearts, "no bounce — the stomp re-auths"
    assert @player.locked
    assert_equal :password, @player.pending_challenge
    refute_equal Player::STOMP_BOUNCE, @player.vy
  end

  def test_a_side_hit_forces_the_re_auth
    @enemy.on_collision(@player, build_args(tick_count: 0))
    refute @enemy.alive
    assert_equal Player::MAX_HEARTS - 1, @player.hearts
    assert @player.locked
  end

  def test_an_invincible_player_is_untouched
    @player.hurt(build_args(tick_count: 0)) # blink window open
    @enemy.on_collision(@player, build_args(tick_count: 1))

    assert @enemy.alive
    assert_equal Player::MAX_HEARTS, @player.hearts
    refute @player.locked
  end

  def test_ignores_a_non_player_partner
    other = TotpEnemy.new(x: @player.x)
    @enemy.on_collision(other, build_args(tick_count: 0))
    assert @enemy.alive
  end
end
