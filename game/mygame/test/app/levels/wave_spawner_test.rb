require_relative "../../test_helper"

class WaveSpawnerTest < Minitest::Test
  include GameTest

  def setup
    @level = Level.new
    @spawner = WaveSpawner.new(@level)
  end

  def test_spawns_nothing_before_the_interval
    @spawner.update(at_tick(0))
    @spawner.update(at_tick(WaveSpawner::INTERVAL - 1))

    assert_empty @level.enemies
  end

  def test_spawns_one_enemy_per_interval
    @spawner.update(at_tick(0))
    @spawner.update(at_tick(WaveSpawner::INTERVAL))

    assert_equal 1, @level.enemies.length
  end

  def test_stops_spawning_at_the_alive_cap
    12.times { |i| @spawner.update(at_tick(i * WaveSpawner::INTERVAL)) }

    assert_equal WaveSpawner::CAP, @level.enemies.count(&:alive)
  end

  def test_cycles_through_the_enemy_kinds_in_order
    5.times { |i| @spawner.update(at_tick(i * WaveSpawner::INTERVAL)) }

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
    @spawner.update(at_tick(WaveSpawner::INTERVAL * 2, camera_x: 1000))

    enemy = @level.enemies.last
    assert_equal 1000 - Enemy::WIDTH, enemy.x
    assert_operator enemy.vx, :>, 0
  end

  def test_second_wave_holds_the_right_edge_while_the_camera_sits_at_the_start
    spawn_one
    @spawner.update(at_tick(WaveSpawner::INTERVAL * 2))

    enemy = @level.enemies.last
    assert_equal SCREEN_W, enemy.x
    assert_operator enemy.vx, :<, 0
  end

  def test_right_edge_spawns_clamp_to_the_world_edge
    cam = @level.world_w - SCREEN_W
    @spawner.update(at_tick(0, camera_x: cam))
    @spawner.update(at_tick(WaveSpawner::INTERVAL, camera_x: cam))

    assert_equal @level.world_w - Enemy::WIDTH, @level.enemies.first.x
  end

  private

  def spawn_one
    @spawner.update(at_tick(0))
    @spawner.update(at_tick(WaveSpawner::INTERVAL))
  end

  def at_tick(tick, camera_x: 0)
    build_args(level: @level, tick_count: tick, camera_x: camera_x)
  end
end
