class Level
  attr_reader :enemies, :platforms, :collectables, :holes

  HEART_DROP_CHANCE = 0.20
  REWIND_DROP_CHANCE = 0.25

  def self.build(number)
    case number
    when 1 then PasswordLevel.new
    when 2 then ApiKeyLevel.new
    when 3 then TotpLevel.new
    when 4 then RubyConfLevel.new
    else WelcomeLevel.new
    end
  end

  def initialize
    @enemies = []
    @platforms = []
    @collectables = []
    @holes = []
  end

  def setup(_args) = nil

  def update(_args) = nil

  def on_unlock(_args) = nil

  def complete? = false

  def next_level = nil

  def title = "Authentication Hell"

  def chapter_label = "Chapter #{number + 1}"

  def accent = BLUE

  def world_w = WORLD_W

  def start_x = 0

  def time_limit = LEVEL_TIME_LIMIT

  CERTIFICATE_INSET = 280 # inside Hole.scatter's 700px end margin, so the goal never sits over a pit

  def certificate_at_exit = Certificate.new(x: world_w - CERTIFICATE_INSET)

  def certificate_collected?(_args)
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

  def rewind(seconds, now)
    return unless @started_at
    @started_at = [ @started_at + seconds * 60, now ].min
  end

  def drop_loot(enemy)
    drop = loot_for(enemy)
    @collectables << drop if drop
  end

  def intro_active?(tick) = !@intro_at.nil? && (tick - @intro_at) < LEVEL_INTRO_TICKS

  def intro_elapsed(tick) = tick - @intro_at

  def draw(_args) = nil

  def dialogue(_args) = []

  def dialogue_ready?(_args) = true

  def dialogue_remaining?(args) = @dialogue_index.to_i < dialogue(args).length

  def current_dialogue(args)
    dialogue(args)[@dialogue_index.to_i] if dialogue_remaining?(args) && dialogue_ready?(args)
  end

  def advance_dialogue = @dialogue_index = @dialogue_index.to_i + 1

  def dialogue_hides_scene? = true

  def draw_hud(_args) = nil

  def render_world(_args, _cam) = nil

  def render_floor(_args, _cam) = nil

  def serialize = { level: self.class.name }
  def inspect = serialize.to_s
  def to_s = serialize.to_s

  private

  def loot_for(enemy)
    roll = rand
    if roll < HEART_DROP_CHANCE
      HeartPickup.new(x: enemy.x.clamp(0, world_w - HeartPickup::SIZE), y: GROUND_Y + HeartPickup::LIFT)
    elsif roll < HEART_DROP_CHANCE + REWIND_DROP_CHANCE
      RewindPickup.new(x: enemy.x.clamp(0, world_w - RewindPickup::SIZE),
                       y: GROUND_Y + RewindPickup::LIFT, level: self)
    end
  end
end
