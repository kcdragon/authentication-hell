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

  def update(args)
    @last_wave_at ||= args.state.tick_count
    return if args.state.tick_count - @last_wave_at < INTERVAL
    return if @level.enemies.count(&:alive) >= CAP

    @last_wave_at = args.state.tick_count
    @level.enemies << spawn_at_camera_edge(next_kind, args.state.camera_x || 0)
    @wave_count += 1
  end

  def serialize = { wave_count: @wave_count, last_wave_at: @last_wave_at }
  def inspect = serialize.to_s
  def to_s = serialize.to_s

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
