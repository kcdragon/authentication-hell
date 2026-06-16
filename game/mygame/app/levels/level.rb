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

  # Whether the player has walked to the world's right wall (the player's x clamps
  # to world_w - WIDTH, so this is exact). Levels that finish by reaching the end
  # latch a flag on this in #update, since #complete? is called without args.
  def reached_end?(args) = args.state.player.x >= world_w - Player::WIDTH

  # The level's prompt, drawn while the player is free (not locked) as the top closed
  # caption (a level with a hint builds its copy and draws a Caption); the default is
  # no prompt.
  def draw(_args) = nil

  # The password character classes this level wants collected, or nil if it isn't a
  # collection level. Non-nil makes the tick draw the collected-character HUD tray.
  def password_targets = nil

  # args.state.level rides along in DragonRuby's state export; levels are
  # stateless, so the class name is all the export needs.
  def serialize = { level: self.class.name }
  def inspect = serialize.to_s
  def to_s = serialize.to_s
end
