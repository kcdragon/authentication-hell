class WaveSpawner
  INTERVAL = 150
  CAP = 5
  KINDS = [ TotpEnemy, PasswordEnemy, PasskeyEnemy, BufferingEnemy ]
  SPEED = 3

  def initialize(level)
    @level = level
    @wave_count = 0
    @last_wave_at = nil
  end

  def update(tick, camera_x)
    @last_wave_at ||= tick
    return if tick - @last_wave_at < INTERVAL
    return if @level.enemies.count(&:alive) >= CAP

    @last_wave_at = tick
    @level.enemies << spawn_at_camera_edge(next_kind, camera_x)
    @wave_count += 1
  end

  private

  def next_kind = KINDS[@wave_count % KINDS.length]

  def spawn_at_camera_edge(kind, cam)
    from_left = @wave_count % 2 == 1 && cam > 0
    if from_left
      enemy = kind.new(x: cam - Enemy::WIDTH, level: @level)
      enemy.march_right(SPEED, max: @level.world_w)
    else
      enemy = kind.new(x: [ cam + SCREEN_W, @level.world_w - Enemy::WIDTH ].min, level: @level)
      enemy.march_left(SPEED)
    end
    enemy
  end
end
