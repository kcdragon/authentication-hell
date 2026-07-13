class Level
  attr_reader :enemies, :platforms, :collectables, :holes, :rewind_flashes, :last_rewind_at

  HEART_DROP_CHANCE = 0.30
  REWIND_DROP_CHANCE = 0.35
  GUARD_SLICE = 3

  def self.build(number, game)
    case number
    when 1 then PasswordLevel.new(game)
    when 2 then ApiKeyLevel.new(game)
    when 3 then TotpLevel.new(game)
    when 4 then RubyConfLevel.new(game)
    else WelcomeLevel.new(game)
    end
  end

  def initialize(game)
    @game = game
    @enemies = []
    @platforms = []
    @collectables = []
    @holes = []
    @rewind_flashes = []
  end

  def setup(_frame) = nil

  def update(_frame) = nil

  def on_unlock(_frame) = nil

  def complete? = false

  def next_level = nil

  def title = "Authentication Hell"

  def chapter_label = "Chapter #{number + 1}"

  def accent = BLUE

  def world_w = WORLD_W

  def start_x = 0

  def start_y = GROUND_Y

  def time_limit = LEVEL_TIME_LIMIT

  CERTIFICATE_INSET = 280 # inside Hole.scatter's 700px end margin, so the goal never sits over a pit

  def certificate_at_exit = Certificate.new(x: world_w - CERTIFICATE_INSET)

  def certificate_collected?(_frame)
    @collectables.any? { |c| c.is_a?(Certificate) && !c.alive? }
  end

  def over_hole?(player)
    @holes.any? do |hole|
      overlap = [ player.x + player.w, hole.x + hole.w ].min - [ player.x, hole.x ].max
      overlap > player.w * 3 / 4
    end
  end

  def begin_clock(tick)
    @started_at = tick
    @intro_at = tick
  end

  def progress(tick)
    return 0.0 unless @started_at
    ((tick - @started_at) / (time_limit * 60).to_f).clamp(0.0, 1.0)
  end

  def elapsed(tick)
    return 0 unless @started_at
    tick - @started_at
  end

  def rewind(seconds, now)
    return unless @started_at
    @started_at = [ @started_at + seconds * 60, now ].min
  end

  def remaining_seconds(tick) = time_limit * (1.0 - progress(tick))

  def note_rewind_collected(pickup, tick)
    @last_rewind_at = tick
    @rewind_flashes << RewindFlash.new(x: pickup.x + pickup.w / 2,
                                       y: pickup.y + pickup.h, started_at: tick)
  end

  def expire_rewind_flashes(tick)
    @rewind_flashes = @rewind_flashes.select { |flash| flash.active?(tick) }
  end

  def drop_loot(enemy)
    drop = loot_for(enemy)
    @collectables << drop if drop
  end

  def intro_active?(tick) = !@intro_at.nil? && (tick - @intro_at) < LEVEL_INTRO_TICKS

  def intro_elapsed(tick) = tick - @intro_at

  def draw(_frame) = nil

  def dialogue(_frame) = []

  def dialogue_ready?(_frame) = true

  def dialogue_remaining?(frame) = @dialogue_index.to_i < dialogue(frame).length

  def current_dialogue(frame)
    dialogue(frame)[@dialogue_index.to_i] if dialogue_remaining?(frame) && dialogue_ready?(frame)
  end

  def advance_dialogue = @dialogue_index = @dialogue_index.to_i + 1

  def dialogue_hides_scene? = true

  def draw_hud(_frame) = nil

  def render_world(_frame, _cam, _cam_y = 0) = nil

  def render_floor(_frame, _cam, _cam_y = 0) = nil

  private

  attr_reader :game

  def spawn_exit_certificate
    return if @certificate_spawned
    @collectables << certificate_at_exit
    @certificate_spawned = true
  end

  def certificate_spawned? = @certificate_spawned == true

  def loot_for(enemy)
    roll = rand
    if roll < game.heart_drop_chance
      HeartPickup.new(x: enemy.x.clamp(0, world_w - HeartPickup::SIZE), y: enemy.y + HeartPickup::LIFT)
    elsif roll < game.heart_drop_chance + game.rewind_drop_chance
      RewindPickup.new(x: enemy.x.clamp(0, world_w - RewindPickup::SIZE),
                       y: enemy.y + RewindPickup::LIFT, level: self)
    end
  end

  def enemy_on(kind, platform)
    kind.new(x: platform.x + (platform.w - Enemy::WIDTH) / 2, level: self).patrol_on(platform)
  end

  def guard_perches(player_x, platforms = @platforms)
    platforms.select(&:holds_password)
             .select { |plat| plat.x > player_x + Enemy::SAFE_GAP }
             .sort_by(&:x)
             .each_slice(GUARD_SLICE).map(&:first)
  end
end
