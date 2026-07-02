# Base class for the game's levels — discrete scripted stages. Shared concerns
# (collision/re-auth, camera, hearts, the locked challenge prompt) stay in Main's
# tick. Levels hold their own state as ivars and run under plain MRI; a level that
# talks to the server (the TOTP level) does so from #update via the Network layer,
# whose HTTP/JSON globals are stubbed in tests.
class Level
  attr_reader :enemies, :platforms, :collectables, :holes

  def self.build(number)
    case number
    when 1 then PasswordLevel.new
    when 2 then TotpLevel.new
    else WelcomeLevel.new
    end
  end

  def initialize
    @enemies = []
    @platforms = []
    @collectables = []
    @holes = []
  end

  # Seed the level's enemies / platforms / collectables / holes for this stage.
  def setup(_args) = nil

  # Per-tick hook for scripted stages (e.g. spawning an enemy mid-level once the
  # player does something). Runs every tick after the player + camera update.
  def update(_args) = nil

  # Called once a re-auth clears (the player just unlocked). Lets a level script
  # what happens next, e.g. the welcome level dropping a heal heart.
  def on_unlock(_args) = nil

  # Called when the player picks up a collectable. The heal itself is generic (in
  # Main's tick); this is the level's chance to react.
  def on_collect(_args) = nil

  # Whether the player has satisfied this stage's goal and it should hand off.
  def complete? = false

  # The level to hand off to once complete? (nil for an endless/terminal stage).
  def next_level = nil

  # The level's human-readable name, shown on the intro "chapter card" (the chapter
  # number itself is derived from #number, so each level only supplies a title).
  def title = "Authentication Hell"

  # The accent color for the intro card's eyebrow + rule, [r, g, b]. Mirrors the
  # site's semantic palette; defaults to the primary blue.
  def accent = BLUE

  # The level's playable world width (the player + camera are bounded by it). The
  # main world is many screens wide; a short scripted stage can shrink it (the
  # welcome level fits one screen).
  def world_w = WORLD_W

  # Where Main#setup_level drops the player on entry; the welcome level overrides this default.
  def start_x = 0

  def time_limit = LEVEL_TIME_LIMIT

  # px inset from the right wall where #certificate_at_exit places the goal — clear of
  # the holes (which stop ≥700px from the wall) and within the player's reach.
  CERTIFICATE_INSET = 280

  # The completion certificate at the level's right exit, on the ground. The full-width
  # levels finish by walking into it (was: reaching the wall).
  def certificate_at_exit = Certificate.new(x: world_w - CERTIFICATE_INSET)

  # Whether the level's certificate has been picked up. The pickup loop retires it
  # (alive → false) but leaves it in the collectables list; #complete? runs without
  # args, so levels latch a flag on this in #update.
  def certificate_collected?(_args)
    @collectables.any? { |c| c.is_a?(Certificate) && !c.alive }
  end

  # The top edge of the one-way platform the player is settling onto this frame, or
  # nil if none — so the player asks the level rather than reaching into its
  # platforms. A landing counts only while descending and only if the player's feet
  # crossed the platform's top this frame (prev_y above it, now at/below), so they
  # pass up through it from underneath.
  def platform_landing_top(player, prev_y)
    @platforms.each do |plat|
      top = plat.y + plat.h
      horizontal = player.x + player.w > plat.x && player.x < plat.x + plat.w
      return top if horizontal && prev_y >= top && player.y <= top
    end
    nil
  end

  # Whether the player is over a pit — more than 3/4 of their body overhangs a gap,
  # so the ground check lets them drop instead of landing. Asked by the player
  # rather than exposing the level's holes (empty on pit-less levels).
  def over_hole?(player)
    @holes.any? do |hole|
      overlap = [ player.x + player.w, hole.x + hole.w ].min - [ player.x, hole.x ].max
      overlap > player.w * 3 / 4
    end
  end

  # Stamp the tick the level's clock starts: the intro card runs from here and the
  # countdown/scoring both measure elapsed from here. Main sets it on level entry.
  def begin_clock(tick)
    @started_at = tick
    @intro_at = tick
  end

  # Fraction (0.0–1.0) of the level's time budget elapsed — drives the scrubber and
  # the out-of-time end. Zero before the clock is stamped (the loading frames).
  def progress(tick)
    return 0.0 unless @started_at
    ((tick - @started_at) / (time_limit * 60).to_f).clamp(0.0, 1.0)
  end

  # Ticks the player has spent in the level, for the results card's finish time.
  def run_ticks(tick) = tick - @started_at

  # Whether the level-intro "chapter card" is still playing (world frozen behind it).
  def intro_active?(tick) = !@intro_at.nil? && (tick - @intro_at) < LEVEL_INTRO_TICKS

  # Ticks since the intro card began, driving its fade-in/out alpha.
  def intro_elapsed(tick) = tick - @intro_at

  # The level's prompt, drawn while the player is free (not locked) as the top closed
  # caption (a level with a hint builds its copy and draws a Caption); the default is
  # no prompt.
  def draw(_args) = nil

  # In-level dialogue cards (after the chapter card): an array of messages, each an
  # array of pre-wrapped lines, dismissed one per E-press while the world freezes.
  # Empty by default. Override #dialogue_ready? to hold a message back until its
  # gameplay beat is reached (the welcome level surfaces each hint at its moment); leaving
  # it always-ready front-loads every message at the level's start (the password level).
  def dialogue(_args) = []

  def dialogue_ready?(_args) = true

  def dialogue_remaining?(args) = @dialogue_index.to_i < dialogue(args).length

  def current_dialogue(args)
    dialogue(args)[@dialogue_index.to_i] if dialogue_remaining?(args) && dialogue_ready?(args)
  end

  def advance_dialogue = @dialogue_index = @dialogue_index.to_i + 1

  def dialogue_hides_scene? = true

  # A persistent HUD overlay the level paints by the hearts every tick (the password
  # level's collected-character tray). Most levels have none.
  def draw_hud(_args) = nil

  # World-space entities a level owns that Main's generic render loop doesn't (the TOTP
  # keypad), drawn in the same camera-offset pass as platforms/enemies. No-op by default.
  def render_world(_args, _cam) = nil

  # args.state.level rides along in DragonRuby's state export; a level's own
  # ivars (its entities + bookkeeping) are intentionally left out — the class
  # name is all the export needs, and #setup rebuilds the contents.
  def serialize = { level: self.class.name }
  def inspect = serialize.to_s
  def to_s = serialize.to_s
end
