class RewindPickup < Pickup
  SECONDS = 30
  SIZE = 34
  LIFT = 40

  GLYPH_TRIANGLE_W = 12
  GLYPH_INSET = 6
  GLYPH_TIP_TRIM = 10

  def initialize(x:, y:, level:)
    super(x: x, y: y)
    @level = level
  end

  def on_collision(other, frame)
    return unless other.is_a?(Player) && alive?

    @level.rewind(SECONDS, frame.tick_count)
    super
  end

  def render(frame, camera_x = 0, camera_y = 0)
    bob = bob_offset(frame.tick_count)
    x = @x - camera_x
    y = @y + bob - camera_y
    frame.outputs.sprites << { path: :solid, x: x, y: y, w: SIZE, h: SIZE, r: INK[0], g: INK[1], b: INK[2] }
    frame.outputs.sprites << { path: :solid, x: x + 3, y: y + 3, w: SIZE - 6, h: SIZE - 6,
                             r: BLUE[0], g: BLUE[1], b: BLUE[2] }
    rewind_triangle(frame, x + GLYPH_INSET, y)
    rewind_triangle(frame, x + GLYPH_INSET + GLYPH_TRIANGLE_W - 2, y)
  end

  private

  def rewind_triangle(frame, left, base_y)
    tip_x = left
    back_x = left + GLYPH_TRIANGLE_W
    frame.outputs.sprites << { path: :solid, x: tip_x, y: base_y + SIZE / 2,
                             x2: back_x, y2: base_y + GLYPH_TIP_TRIM,
                             x3: back_x, y3: base_y + SIZE - GLYPH_TIP_TRIM,
                             r: PAPER[0], g: PAPER[1], b: PAPER[2] }.merge(SOLID_TRIANGLE_SOURCE)
  end
end
