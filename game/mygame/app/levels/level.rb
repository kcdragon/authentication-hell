# Base class for the game's levels — discrete scripted stages. Shared concerns
# (collision/re-auth, camera, hearts, the locked challenge prompt) stay in Main's
# tick; levels do no engine I/O, so they load under plain MRI like the entities.
class Level
  def self.build(number)
    case number
    when 1 then PasswordLevel.new
    when 2 then MainLevel.new
    when 3 then GauntletLevel.new
    else TutorialLevel.new
    end
  end

  # Seed args.state.enemies / args.state.platforms for this stage.
  def setup(_args) = nil

  # Per-tick hook for scripted stages (e.g. spawning an enemy mid-level once the
  # player does something). Runs every tick after the player + camera update.
  def update(_args) = nil

  # Called once a re-auth clears (the player just unlocked). Lets a level script
  # what happens next, e.g. the tutorial dropping a heal heart.
  def on_unlock(_args) = nil

  # Called when the player picks up a collectable. The heal itself is generic (in
  # Main's tick); this is the level's chance to react.
  def on_collect(_args) = nil

  # Whether the player has satisfied this stage's goal and it should hand off.
  def complete? = false

  # The level to hand off to once complete? (nil for an endless/terminal stage).
  def next_level = nil

  # Whether the keyboard melee can defeat enemies on this level.
  def melee? = true

  # The level's human-readable name, shown on the intro "chapter card" (the chapter
  # number itself is derived from #number, so each level only supplies a title).
  def title = "Authentication 101"

  # The accent color for the intro card's eyebrow + rule, [r, g, b]. Mirrors the
  # site's semantic palette; defaults to the primary blue.
  def accent = BLUE

  # The level's playable world width (the player + camera are bounded by it). The
  # main world is many screens wide; a short scripted stage can shrink it (the
  # tutorial fits one screen).
  def world_w = WORLD_W

  # px inset from the right wall where #certificate_at_exit places the goal — clear of
  # the holes (which stop ≥700px from the wall) and within the player's reach.
  CERTIFICATE_INSET = 280

  # The completion certificate at the level's right exit, on the ground. The full-width
  # levels finish by walking into it (was: reaching the wall).
  def certificate_at_exit = Certificate.new(x: world_w - CERTIFICATE_INSET)

  # Whether the level's certificate has been picked up. The pickup loop retires it
  # (alive → false) but leaves it in the collectables list; #complete? runs without
  # args, so levels latch a flag on this in #update.
  def certificate_collected?(args)
    (args.state.collectables || []).any? { |c| c.is_a?(Certificate) && !c.alive }
  end

  # The level's prompt, drawn while the player is free (not locked) as the top closed
  # caption (a level with a hint builds its copy and draws a Caption); the default is
  # no prompt.
  def draw(_args) = nil

  # Start-of-level dialogue (after the chapter card, before play): an array of
  # messages, each an array of pre-wrapped lines, dismissed one per E-press. Empty
  # by default — the level starts straight into play.
  def dialogue = []

  def dialogue_remaining? = @dialogue_index.to_i < dialogue.length

  def current_dialogue = dialogue[@dialogue_index.to_i]

  def advance_dialogue = @dialogue_index = @dialogue_index.to_i + 1

  # The password character classes this level wants collected, or nil if it isn't a
  # collection level. Non-nil makes the tick draw the collected-character HUD tray
  # (which then reads #password_required_per_class off the collection level).
  def password_targets = nil

  # args.state.level rides along in DragonRuby's state export; levels are
  # stateless, so the class name is all the export needs.
  def serialize = { level: self.class.name }
  def inspect = serialize.to_s
  def to_s = serialize.to_s
end
