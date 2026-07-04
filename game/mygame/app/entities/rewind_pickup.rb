class RewindPickup
  include Collectable

  SECONDS = 30
  SIZE = 34
  LIFT = 40
  BOB = 6

  GLYPH_TRIANGLE_W = 12
  GLYPH_INSET = 6
  GLYPH_TIP_TRIM = 10

  attr_accessor :x, :y, :w, :h

  def initialize(x:, y:, level:)
    @x = x
    @y = y
    @w = SIZE
    @h = SIZE
    @level = level
    @alive = true
  end

  def hitbox = { x: @x, y: @y, w: @w, h: @h }

  def on_collision(other, args)
    return unless other.is_a?(Player) && alive?

    @level.rewind(SECONDS, args.state.tick_count)
    super
  end

  def collect(_player) = nil

  def render(args, camera_x = 0)
    bob = bob_offset(args.state.tick_count)
    x = @x - camera_x
    y = @y + bob
    args.outputs.solids << { x: x, y: y, w: SIZE, h: SIZE, r: INK[0], g: INK[1], b: INK[2] }
    args.outputs.solids << { x: x + 3, y: y + 3, w: SIZE - 6, h: SIZE - 6,
                             r: BLUE[0], g: BLUE[1], b: BLUE[2] }
    rewind_triangle(args, x + GLYPH_INSET, y)
    rewind_triangle(args, x + GLYPH_INSET + GLYPH_TRIANGLE_W - 2, y)
  end

  private

  def rewind_triangle(args, left, base_y)
    tip_x = left
    back_x = left + GLYPH_TRIANGLE_W
    args.outputs.solids << { x: tip_x, y: base_y + SIZE / 2,
                             x2: back_x, y2: base_y + GLYPH_TIP_TRIM,
                             x3: back_x, y3: base_y + SIZE - GLYPH_TIP_TRIM,
                             r: PAPER[0], g: PAPER[1], b: PAPER[2] }
  end
end
