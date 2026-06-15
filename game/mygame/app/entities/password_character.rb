# A collectable password character — the password level's quarry. Reuses the
# password enemy's amber padlock art so it still reads as a "password enemy," but
# walking into it is friendly: it carries one of the four character classes
# (uppercase, lowercase, digit, symbol) and a representative glyph, and collecting
# it records that class on the player. Lives in args.state.collectables; pickup
# collision (and the no-harm collect) is wired in Main's tick.
class PasswordCharacter
  CLASSES = %i[upper lower digit symbol] # the four targets, in display order
  # A representative glyph per class (ambiguous look-alikes like 0/O/1/l omitted so
  # the collected character reads clearly in the HUD tray).
  GLYPHS = {
    upper: "ABCDEFGHJKLMNPQRSTUVWXYZ",
    lower: "abcdefghijkmnpqrstuvwxyz",
    digit: "23456789",
    symbol: "!@#$%&*?"
  }.freeze
  SIZE = Enemy::HEIGHT # padlock drawn at the enemy's body height so it matches the foe

  attr_accessor :x, :y, :w, :h, :alive, :klass, :glyph

  def initialize(x:, klass:, y: GROUND_Y, glyph: nil)
    @x = x
    @y = y # GROUND_Y for a floor padlock, a platform's top edge for a perched one
    @w = SIZE
    @h = SIZE
    @klass = klass
    @glyph = glyph || GLYPHS.fetch(klass).chars.sample
    @alive = true
  end

  def hitbox = { x: @x, y: @y, w: @w, h: @h }

  # Walked into: record this class's glyph on the player (first one of a class wins;
  # extra padlocks of an already-held class are consumed but add nothing).
  def collect(args)
    args.state.player.collected_password_characters[@klass] ||= @glyph
  end

  # The amber padlock (same art as the password enemy) with the carried glyph in an
  # ink-bordered chip above it, so the player can see which character it holds.
  def render(args, camera_x = 0)
    sx = @x - camera_x
    args.outputs.sprites << { x: sx, y: @y, w: SIZE, h: SIZE, path: "sprites/enemies/password.png" }

    chip_w = 34
    chip_h = 34
    chip_x = sx + (SIZE - chip_w) / 2
    chip_y = @y + SIZE - 6
    args.outputs.solids << { x: chip_x, y: chip_y, w: chip_w, h: chip_h, r: INK[0], g: INK[1], b: INK[2] }
    args.outputs.solids << { x: chip_x + 3, y: chip_y + 3, w: chip_w - 6, h: chip_h - 6,
                             r: AMBER[0], g: AMBER[1], b: AMBER[2] }
    args.outputs.labels << { x: chip_x + chip_w / 2, y: chip_y + chip_h / 2 + 1, text: @glyph,
                             size_px: 22, font: FONT_MONO_B, r: INK[0], g: INK[1], b: INK[2],
                             anchor_x: 0.5, anchor_y: 0.5 }
  end

  # DragonRuby exports args.state for its dev tools; give it a plain-hash view (see
  # the same pattern on HeartPickup/Enemy).
  def serialize = { x: @x, y: @y, w: @w, h: @h, alive: @alive, klass: @klass, glyph: @glyph }
  def inspect = serialize.to_s
  def to_s = serialize.to_s
end
