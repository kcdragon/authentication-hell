require_relative "../../test_helper"

class HeartPickupTest < Minitest::Test
  include GameTest

  def test_starts_alive
    assert HeartPickup.new(x: 100, y: GROUND_Y).alive?
  end

  def test_on_collision_with_the_player_heals_one_heart_and_retires
    player = Player.new
    player.instance_variable_set(:@hearts, 1)
    heart = HeartPickup.new(x: player.x, y: player.y)
    heart.on_collision(player, build_args(player: player))
    assert_equal 2, player.hearts
    refute heart.alive?
  end

  def test_healing_is_capped_at_the_max
    player = Player.new
    heart = HeartPickup.new(x: player.x, y: player.y)
    heart.on_collision(player, build_args(player: player))
    assert_equal Player::MAX_HEARTS, player.hearts
  end

  def test_ignores_a_non_player_collider
    heart = HeartPickup.new(x: 100, y: GROUND_Y)
    heart.on_collision(Object.new, build_args)
    assert heart.alive?
  end
end
