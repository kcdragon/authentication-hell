class RubyConfLevel < Level
  attr_reader :plants

  RUBY_COUNT = 8
  GROUND_RUBY_COUNT = 5
  PLATFORM_RUBY_COUNT = RUBY_COUNT - GROUND_RUBY_COUNT

  PLANT_START_X = 100
  PLANT_END_X = 5900
  GROUND_PLANT_PITCH = 100
  GROUND_PLANT_SCALES = [ 1.0, 0.8, 1.15, 0.9 ].freeze
  PLATFORM_PLANT_SCALE = 0.7
  PLATFORM_PLANT_INSET = 8
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
    @plants = ground_plants + platform_plants
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

  def ground_plants
    kinds = Plant::KINDS.keys
    count = (PLANT_END_X - PLANT_START_X).fdiv(GROUND_PLANT_PITCH).floor
    (0..count).map do |i|
      plant = Plant.new(x: PLANT_START_X + i * GROUND_PLANT_PITCH,
                        kind: kinds[i % kinds.length],
                        scale: GROUND_PLANT_SCALES[i % GROUND_PLANT_SCALES.length])
      plant unless over_pit?(plant)
    end.compact
  end

  def over_pit?(plant)
    @holes.any? do |hole|
      plant.x < hole.x + hole.w + HOLE_MARGIN && plant.x + plant.w > hole.x - HOLE_MARGIN
    end
  end

  def platform_plants
    kinds = Plant::KINDS.keys
    index = 0
    @platforms.flat_map do |plat|
      plants = []
      x = plat.x + PLATFORM_PLANT_INSET
      loop do
        plant = Plant.new(x: x, y: plat.y + plat.h, kind: kinds[index % kinds.length],
                          scale: PLATFORM_PLANT_SCALE)
        break if plant.x + plant.w > plat.x + plat.w - PLATFORM_PLANT_INSET

        plants << plant
        index += 1
        x += (plant.w * 0.7).to_i
      end
      plants
    end
  end

  def ground_rubies
    grounded = @plants.select { |p| p.y == GROUND_Y }
    hiding_spots(grounded, GROUND_RUBY_COUNT).map do |plant|
      RubyPickup.new(x: centered_in(plant), y: GROUND_Y + RubyPickup::LIFT)
    end
  end

  def platform_rubies
    perches = @platforms.select(&:holds_password).sort_by(&:x)
    hiding_spots(perches, PLATFORM_RUBY_COUNT).map do |plat|
      plant = plants_on(plat).first
      RubyPickup.new(x: centered_in(plant), y: plat.y + plat.h)
    end
  end

  def plants_on(plat)
    top = plat.y + plat.h
    @plants.select { |p| p.y == top && p.x >= plat.x && p.x + p.w <= plat.x + plat.w }
  end

  def centered_in(plant)
    plant.x + (plant.w - RubyPickup::SIZE) / 2
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
