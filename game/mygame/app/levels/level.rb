# Base class for the game's levels — discrete scripted stages. Shared concerns
# (collision/re-auth, camera, hearts, the locked challenge prompt) stay in Main's
# tick; levels do no engine I/O, so they load under plain MRI like the entities.
class Level
  # Seed args.state.enemies / args.state.platforms for this stage.
  def setup(_args) = nil

  # Per-tick hook for scripted stages (e.g. spawning an enemy mid-level once the
  # player does something). Runs every tick after the player + camera update.
  def update(_args) = nil

  # Whether the keyboard melee can defeat enemies on this level.
  def melee? = true

  # The level's HUD overlay (drawn only while the player is free, not locked).
  def draw(_args) = nil

  # args.state.level rides along in DragonRuby's state export; levels are
  # stateless, so the class name is all the export needs.
  def serialize = { level: self.class.name }
  def inspect = serialize.to_s
  def to_s = serialize.to_s
end
