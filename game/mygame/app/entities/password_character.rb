# A collectable password character — the password level's quarry. Drawn as just the
# glyph it carries, floating a little above its surface; walking into it is friendly:
# it holds one of the four character classes (uppercase, lowercase, digit, symbol)
# and a representative glyph, and collecting it records that class on the player.
# Lives in args.state.collectables; pickup collision (and the no-harm collect) is
# wired in Main's tick.
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
  # Face + text colors per class, so the four password classes read apart at a glance
  # (reuses the site's semantic palette). Dark faces take cream text; amber keeps ink.
  CLASS_FACE = { upper: BLUE, lower: GREEN, digit: AMBER, symbol: PURPLE }.freeze
  CLASS_INK  = { upper: PAPER, lower: PAPER, digit: INK, symbol: PAPER }.freeze
  SIZE = Enemy::HEIGHT # the layout cell the glyph chip centers within
  CHIP = 50 # the glyph chip's drawn size
  FLOAT_GAP = 16 # how far the chip hovers above its surface

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

  # The chip floats off the surface, so collection tracks that rect, not the cell.
  def chip_rect = { x: @x + (SIZE - CHIP) / 2, y: @y + FLOAT_GAP, w: CHIP, h: CHIP }

  def hitbox = chip_rect

  # Walked into: append this class's glyph to the player's tally for that class. The
  # level wants several of each class (see PasswordLevel::REQUIRED_PER_CLASS), so each
  # padlock of a class counts; over-collecting past the goal is harmless.
  def collect(args)
    (args.state.player.collected_password_characters[@klass] ||= []) << @glyph
  end

  # The carried glyph in a class-colored, ink-bordered chip, hovering above its surface.
  def render(args, camera_x = 0)
    c = chip_rect
    cx = c[:x] - camera_x
    cy = c[:y]
    face = CLASS_FACE.fetch(@klass)
    ink = CLASS_INK.fetch(@klass)
    args.outputs.solids << { x: cx, y: cy, w: CHIP, h: CHIP, r: INK[0], g: INK[1], b: INK[2] }
    args.outputs.solids << { x: cx + 3, y: cy + 3, w: CHIP - 6, h: CHIP - 6,
                             r: face[0], g: face[1], b: face[2] }
    args.outputs.labels << { x: cx + CHIP / 2, y: cy + CHIP / 2 + 1, text: @glyph,
                             size_px: 32, font: FONT_MONO_B, r: ink[0], g: ink[1], b: ink[2],
                             anchor_x: 0.5, anchor_y: 0.5 }
  end

  # DragonRuby exports args.state for its dev tools; give it a plain-hash view (see
  # the same pattern on HeartPickup/Enemy).
  def serialize = { x: @x, y: @y, w: @w, h: @h, alive: @alive, klass: @klass, glyph: @glyph }
  def inspect = serialize.to_s
  def to_s = serialize.to_s
end
