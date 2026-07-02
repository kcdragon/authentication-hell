require_relative "../../../test_helper"

# The tutorial gate can't be stomped — running into it (even from above) forces the
# re-auth, unlike an ordinary enemy. The end-to-end stomp behavior is driven through
# the CollisionManager so both sides (enemy fate + player reaction) run as in-game.
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

  def test_is_not_stompable
    refute @enemy.stompable?
  end

  def test_a_stomp_forces_the_re_auth_instead_of_defeating_it
    @player.y = @enemy.y + @enemy.h - 6 # feet on its head, descending
    @player.vy = -5
    @player.grounded = false

    manager = CollisionManager.new
    manager.add(@enemy)   # enemy first, as Main registers them
    manager.add(@player)
    manager.resolve(build_args(player: @player, tick_count: 0))

    refute @enemy.alive
    assert_equal Player::MAX_HEARTS - 1, @player.hearts, "no bounce — the stomp re-auths"
    assert @player.locked
    assert_equal :password, @player.pending_challenge
    refute_equal Player::STOMP_BOUNCE, @player.vy
  end
end
