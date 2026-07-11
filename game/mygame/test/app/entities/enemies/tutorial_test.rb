require_relative "../../../test_helper"

class TutorialEnemyTest < Minitest::Test
  include GameTest

  def setup
    @player = Player.new
    @enemy = TutorialEnemy.new(x: @player.x, level: enemy_level)
  end

  def test_looks_and_authenticates_like_a_password_enemy
    assert_kind_of PasswordEnemy, @enemy
    assert_equal :password, @enemy.auth
  end

  def test_counts_as_a_password_defeat
    assert_equal "password", @enemy.kind
  end

  def test_is_not_stompable
    refute @enemy.stompable?
  end

  def test_a_stomp_forces_the_re_auth_instead_of_defeating_it
    @player.y = @enemy.y + @enemy.h - 6
    @player.vy = -5
    @player.grounded = false

    manager = CollisionManager.new
    manager.add(@enemy)
    manager.add(@player)
    manager.resolve(build_frame(player: @player, tick_count: 0))

    refute @enemy.alive
    assert_equal Player::MAX_HEARTS - 1, @player.hearts, "no bounce — the stomp re-auths"
    assert @player.locked
    assert_equal :password, @player.pending_challenge
    refute_equal Player::STOMP_BOUNCE, @player.vy
  end
end
