class RubyConfLevel < Level
  attr_reader :plants

  RUBY_COUNT = 8
  GROUND_RUBY_COUNT = 5
  PLATFORM_RUBY_COUNT = RUBY_COUNT - GROUND_RUBY_COUNT

  PLANT_COUNT = 14
  PLANT_START_X = 500
  PLANT_END_X = 6000
  HOLE_MARGIN = 20

  WAVE_INTERVAL = 150
  WAVE_CAP = 5
  WAVE_KINDS = [ TotpEnemy, PasswordEnemy, PasskeyEnemy, BufferingEnemy ]
  ENEMY_SPEED = 3

  def number = 3

  def title = "RubyConf Field Trip"

  def chapter_label = "Bonus Chapter"

  def accent = RUBY

  def dialogue(_args)
    [
      [ "Training complete! You've earned",
        "a field trip to RubyConf" ],
      [ "Collect all #{RUBY_COUNT} rubies hidden in the",
        "wildflowers, then head to the exit" ]
    ]
  end

  def setup(_args)
    @platforms = Platform.scatter
    @holes = Hole.scatter
    @plants = scatter_plants
    @collectables = ground_rubies + platform_rubies
    @enemies = []
    @wave_count = 0
    @last_wave_at = nil
  end

  def update(args)
    spawn_waves(args)
    spawn_exit_certificate if all_rubies_collected? && !@certificate_spawned
    @cleared = true if certificate_collected?(args)
  end

  def complete? = @cleared == true

  def render_world(args, cam)
    @plants.each { |plant| plant.render(args, cam) }
  end

  def draw(args)
    lines = if all_rubies_collected?
      [ "All rubies found —", "head right to finish →" ]
    else
      [ "#{collected_rubies}/#{RUBY_COUNT} rubies" ]
    end
    Caption.new(args, lines).draw
  end

  def all_rubies_collected? = @collectables.none? { |c| c.is_a?(RubyPickup) && c.alive? }

  def collected_rubies = @collectables.count { |c| c.is_a?(RubyPickup) && !c.alive? }

  private

  def scatter_plants
    kinds = Plant::KINDS.keys
    pitch = (PLANT_END_X - PLANT_START_X).fdiv(PLANT_COUNT - 1)
    PLANT_COUNT.times.map do |i|
      kind = kinds[i % kinds.length]
      width = Plant::KINDS.fetch(kind)[:w]
      x = clear_of_holes(PLANT_START_X + (i * pitch).to_i, width)
      Plant.new(x: x, kind: kind)
    end
  end

  def clear_of_holes(x, width)
    blocking = @holes.find do |hole|
      x < hole.x + hole.w + HOLE_MARGIN && x + width > hole.x - HOLE_MARGIN
    end
    return x unless blocking

    clear_of_holes((blocking.x + blocking.w + HOLE_MARGIN).to_i, width)
  end

  def ground_rubies
    hiding_spots(@plants, GROUND_RUBY_COUNT).map do |plant|
      RubyPickup.new(x: plant.x + (plant.w - RubyPickup::SIZE) / 2,
                     y: GROUND_Y + RubyPickup::LIFT)
    end
  end

  def platform_rubies
    perches = @platforms.select(&:holds_password).sort_by(&:x)
    hiding_spots(perches, PLATFORM_RUBY_COUNT).map do |plat|
      RubyPickup.new(x: plat.x + (plat.w - RubyPickup::SIZE) / 2, y: plat.y + plat.h)
    end
  end

  def hiding_spots(spots, count)
    slice = [ spots.length.fdiv(count).ceil, 1 ].max
    spots.each_slice(slice).map(&:first).first(count)
  end

  def spawn_waves(args)
    @last_wave_at ||= args.state.tick_count
    return if args.state.tick_count - @last_wave_at < WAVE_INTERVAL
    return if @enemies.count(&:alive) >= WAVE_CAP

    @last_wave_at = args.state.tick_count
    cam = args.state.camera_x || 0
    kind = WAVE_KINDS[@wave_count % WAVE_KINDS.length]
    @enemies << spawn_at_camera_edge(kind, cam)
    @wave_count += 1
  end

  def spawn_at_camera_edge(kind, cam)
    from_left = @wave_count % 2 == 1 && cam > 0
    if from_left
      enemy = kind.new(x: cam - Enemy::WIDTH, level: self)
      enemy.march_right(ENEMY_SPEED, max: world_w)
    else
      enemy = kind.new(x: [ cam + SCREEN_W, world_w - Enemy::WIDTH ].min, level: self)
      enemy.march_left(ENEMY_SPEED)
    end
    enemy
  end

  def spawn_exit_certificate
    @collectables << certificate_at_exit
    @certificate_spawned = true
  end
end
