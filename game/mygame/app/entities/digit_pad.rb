# A key on the TOTP level's number pad
class DigitPad
  SIZE = 52          # the keycap square
  FLASH_TICKS = 12   # how long the green press-flash lasts

  attr_accessor :x, :y, :w, :h, :digit

  def initialize(x:, y:, digit:)
    @x = x
    @y = y
    @w = SIZE
    @h = SIZE
    @digit = digit
    @pressed_at = nil
  end

  def hitbox = { x: @x, y: @y, w: @w, h: @h }

  def press(tick) = @pressed_at = tick

  def flashing?(tick) = @pressed_at && tick - @pressed_at < FLASH_TICKS

  # A purple keycap (ink border + face) with the digit; flashes green for a beat on press.
  def render(args, camera_x = 0)
    sx = @x - camera_x
    face = flashing?(args.state.tick_count) ? GREEN : PURPLE
    args.outputs.solids << { x: sx, y: @y, w: @w, h: @h, r: INK[0], g: INK[1], b: INK[2] }
    args.outputs.solids << { x: sx + 3, y: @y + 3, w: @w - 6, h: @h - 6,
                             r: face[0], g: face[1], b: face[2] }
    args.outputs.labels << { x: sx + @w / 2, y: @y + @h / 2 + 1, text: @digit.to_s,
                             size_px: 28, font: FONT_MONO_B, r: PAPER[0], g: PAPER[1], b: PAPER[2],
                             anchor_x: 0.5, anchor_y: 0.5 }
  end

  def serialize = { x: @x, y: @y, w: @w, h: @h, digit: @digit }
  def inspect = serialize.to_s
  def to_s = serialize.to_s
end
