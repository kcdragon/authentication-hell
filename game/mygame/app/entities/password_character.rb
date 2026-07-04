class PasswordCharacter
  include Collectable

  CLASSES = %i[upper lower digit symbol]
  UNAMBIGUOUS_GLYPHS = {
    upper: "ABCDEFGHJKLMNPQRSTUVWXYZ",
    lower: "abcdefghijkmnpqrstuvwxyz",
    digit: "23456789",
    symbol: "!@#$%&*?"
  }.freeze
  CLASS_FACE = { upper: BLUE, lower: GREEN, digit: AMBER, symbol: PURPLE }.freeze
  CLASS_INK  = { upper: PAPER, lower: PAPER, digit: INK, symbol: PAPER }.freeze

  def self.klass_of(glyph) = CLASSES.find { |k| UNAMBIGUOUS_GLYPHS.fetch(k).include?(glyph) }
  SIZE = Enemy::HEIGHT
  CHIP = 50
  FLOAT_GAP = 16

  attr_accessor :x, :y, :w, :h, :klass, :glyph

  def initialize(x:, klass:, y: GROUND_Y, glyph: nil)
    @x = x
    @y = y
    @w = SIZE
    @h = SIZE
    @klass = klass
    @glyph = glyph || UNAMBIGUOUS_GLYPHS.fetch(klass).chars.sample
    @alive = true
  end

  def chip_rect = { x: @x + (SIZE - CHIP) / 2, y: @y + FLOAT_GAP, w: CHIP, h: CHIP }

  def hitbox = chip_rect

  def collect(_player) = nil

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
end
