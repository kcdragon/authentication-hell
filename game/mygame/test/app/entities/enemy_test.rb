require_relative "../../test_helper"

class EnemyTest < Minitest::Test
  include GameTest

  def setup
    @player = Player.new
  end

  def stomp_the(enemy)
    @player.y = enemy.y + enemy.h - 6
    @player.vy = -5
    @player.grounded = false
  end

  def test_is_stompable_by_default
    assert TotpEnemy.new(x: 0, level: enemy_level).stompable?
  end

  def test_spawns_on_the_ground
    assert_equal GROUND_Y, TotpEnemy.new(x: 0, level: enemy_level).y
  end

  def test_patrol_on_stations_it_atop_the_platform
    platform = Platform.new(x: 500, y: 220, w: 200, h: Platform::H)
    enemy = TotpEnemy.new(x: 560, level: enemy_level).patrol_on(platform)

    assert_equal platform.y + platform.h, enemy.y
    assert_equal platform.x, enemy.patrol_min_x
    assert_equal platform.x + platform.w - enemy.w, enemy.patrol_max_x
  end

  def test_patrol_on_pulls_a_stray_spawn_inside_the_platform
    platform = Platform.new(x: 500, y: 220, w: 200, h: Platform::H)
    enemy = TotpEnemy.new(x: 0, level: enemy_level).patrol_on(platform)

    assert_equal platform.x, enemy.x
  end

  def test_a_platform_patrol_never_walks_off_the_edge
    platform = Platform.new(x: 500, y: 220, w: 200, h: Platform::H)
    enemy = TotpEnemy.new(x: 560, level: enemy_level).patrol_on(platform)

    600.times do
      enemy.update
      assert_operator enemy.x, :>=, platform.x
      assert_operator enemy.x + enemy.w, :<=, platform.x + platform.w
    end
  end

  def test_a_stomp_defeats_it_on_a_platform
    platform = Platform.new(x: 500, y: 220, w: 200, h: Platform::H)
    enemy = TotpEnemy.new(x: @player.x, level: enemy_level).patrol_on(platform)
    stomp_the(enemy)
    enemy.on_collision(@player, build_frame)

    refute enemy.alive
  end

  def test_a_stomp_defeats_it
    enemy = PasswordEnemy.new(x: @player.x, level: enemy_level)
    stomp_the(enemy)
    enemy.on_collision(@player, build_frame)

    refute enemy.alive
  end

  def test_a_buffering_enemy_is_spent_on_a_side_hit
    enemy = BufferingEnemy.new(x: @player.x, level: enemy_level)
    enemy.on_collision(@player, build_frame(tick_count: 0))
    refute enemy.alive
  end

  def test_a_side_hit_defeats_it
    enemy = TotpEnemy.new(x: @player.x, level: enemy_level)
    enemy.on_collision(@player, build_frame(tick_count: 0))
    refute enemy.alive
  end

  def test_survives_a_hit_while_the_player_is_invincible
    @player.hurt(build_frame(tick_count: 0))
    enemy = TotpEnemy.new(x: @player.x, level: enemy_level)
    enemy.on_collision(@player, build_frame(tick_count: 1))
    assert enemy.alive
  end

  def test_leaves_the_player_alone
    enemy = TotpEnemy.new(x: @player.x, level: enemy_level)
    enemy.on_collision(@player, build_frame(tick_count: 0))
    assert_equal Player::MAX_HEARTS, @player.hearts, "the player's reaction is its own concern"
    refute @player.locked
  end

  def test_ignores_a_non_player_partner
    enemy = TotpEnemy.new(x: @player.x, level: enemy_level)
    other = TotpEnemy.new(x: @player.x, level: enemy_level)
    enemy.on_collision(other, build_frame(tick_count: 0))
    assert enemy.alive, "enemies don't collide with each other"
    assert other.alive
  end

  def test_a_defeated_enemy_drops_loot_into_its_level
    level = Level.new(build_game)
    drop = HeartPickup.new(x: 0, y: GROUND_Y)
    level.define_singleton_method(:loot_for) { |_e| drop }
    enemy = TotpEnemy.new(x: @player.x, level: level)

    enemy.on_collision(@player, build_frame(tick_count: 0))
    refute enemy.alive
    assert_includes level.collectables, drop
  end

  def test_a_surviving_enemy_drops_no_loot
    level = Level.new(build_game)
    level.define_singleton_method(:loot_for) { |_e| flunk "no drop unless it dies" }
    @player.hurt(build_frame(tick_count: 0))
    enemy = TotpEnemy.new(x: @player.x, level: level)

    enemy.on_collision(@player, build_frame(tick_count: 1))
    assert enemy.alive
    assert_empty level.collectables
  end
end
