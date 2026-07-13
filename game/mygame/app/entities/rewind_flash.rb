class RewindFlash
  LABEL = format("+0:%02d", RewindPickup::SECONDS)
  RISE = 30

  attr_reader :x, :y, :started_at

  def initialize(x:, y:, started_at:)
    @x = x
    @y = y
    @started_at = started_at
  end

  def active?(tick) = tick - @started_at < REWIND_FLASH_TICKS

  def rise(tick) = RISE * elapsed_fraction(tick)

  def alpha(tick) = (255 * (1.0 - elapsed_fraction(tick))).round.clamp(0, 255)

  def render(frame, camera_x = 0, camera_y = 0)
    tick = frame.tick_count
    frame.outputs.labels << { x: @x - camera_x, y: @y + rise(tick) - camera_y,
                              text: LABEL, size_px: 22, font: FONT_MONO_B,
                              r: GREEN[0], g: GREEN[1], b: GREEN[2], a: alpha(tick),
                              anchor_x: 0.5, anchor_y: 0 }
  end

  private

  def elapsed_fraction(tick)
    ((tick - @started_at) / REWIND_FLASH_TICKS.to_f).clamp(0.0, 1.0)
  end
end
