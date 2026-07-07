class DigitPad
  SIZE = 52
  FLASH_TICKS = 12

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

  def render(frame, camera_x = 0, camera_y = 0)
    sx = @x - camera_x
    sy = @y - camera_y
    face = flashing?(frame.tick_count) ? GREEN : PURPLE
    frame.outputs.sprites << { path: :solid, x: sx, y: sy, w: @w, h: @h, r: INK[0], g: INK[1], b: INK[2] }
    frame.outputs.sprites << { path: :solid, x: sx + 3, y: sy + 3, w: @w - 6, h: @h - 6,
                             r: face[0], g: face[1], b: face[2] }
    frame.outputs.labels << { x: sx + @w / 2, y: sy + @h / 2 + 1, text: @digit.to_s,
                             size_px: 28, font: FONT_MONO_B, r: PAPER[0], g: PAPER[1], b: PAPER[2],
                             anchor_x: 0.5, anchor_y: 0.5 }
  end
end
