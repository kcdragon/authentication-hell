require_relative "../../test_helper"

class WaveSpawnerTest < Minitest::Test
  include GameTest

  def setup
    @level = Level.new(build_game)
    @spawner = WaveSpawner.new(@level)
  end

  def test_spawns_nothing_before_the_interval
    @spawner.update(0, 0)
    @spawner.update(WaveSpawner::INTERVAL - 1, 0)

    assert_empty @level.enemies
  end

  def test_spawns_one_enemy_per_interval
    @spawner.update(0, 0)
    @spawner.update(WaveSpawner::INTERVAL, 0)

    assert_equal 1, @level.enemies.length
  end

  def test_stops_spawning_at_the_alive_cap
    12.times { |i| @spawner.update(i * WaveSpawner::INTERVAL, 0) }

    assert_equal WaveSpawner::CAP, @level.enemies.count(&:alive)
  end

  def test_platform_guards_leave_the_ground_cap_untouched
    platform = Platform.new(x: 500, y: 220, w: 200, h: Platform::H)
    WaveSpawner::CAP.times do
      @level.enemies << TotpEnemy.new(x: 560, level: @level).patrol_on(platform)
    end

    12.times { |i| @spawner.update(i * WaveSpawner::INTERVAL, 0) }

    grounded = @level.enemies.count { |e| e.alive && e.y == GROUND_Y }
    assert_equal WaveSpawner::CAP, grounded, "guards standing watch upstairs don't throttle the waves"
  end

  def test_cycles_through_the_enemy_kinds_in_order
    5.times { |i| @spawner.update(i * WaveSpawner::INTERVAL, 0) }

    assert_equal WaveSpawner::KINDS, @level.enemies.map(&:class)
  end

  def test_first_wave_marches_in_from_the_right_camera_edge
    spawn_one

    enemy = @level.enemies.first
    assert_equal SCREEN_W, enemy.x
    assert_operator enemy.vx, :<, 0
  end

  def test_second_wave_flanks_from_the_left_once_the_camera_has_moved
    spawn_one
    @spawner.update(WaveSpawner::INTERVAL * 2, 1000)

    enemy = @level.enemies.last
    assert_equal 1000 - Enemy::WIDTH, enemy.x
    assert_operator enemy.vx, :>, 0
  end

  def test_second_wave_holds_the_right_edge_while_the_camera_sits_at_the_start
    spawn_one
    @spawner.update(WaveSpawner::INTERVAL * 2, 0)

    enemy = @level.enemies.last
    assert_equal SCREEN_W, enemy.x
    assert_operator enemy.vx, :<, 0
  end

  def test_right_edge_spawns_clamp_to_the_world_edge
    cam = @level.world_w - SCREEN_W
    @spawner.update(0, cam)
    @spawner.update(WaveSpawner::INTERVAL, cam)

    assert_equal @level.world_w - Enemy::WIDTH, @level.enemies.first.x
  end

  private

  def spawn_one
    @spawner.update(0, 0)
    @spawner.update(WaveSpawner::INTERVAL, 0)
  end
end
