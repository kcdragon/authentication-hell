class BufferingEnemy < Enemy
  AUTH = nil
  COLOR = { r: MUTED[0], g: MUTED[1], b: MUTED[2] }

  RADIUS = 26
  SEGMENTS = 12
  SEG_W = 8
  SEG_H = 5
  TICKS_PER_SEGMENT = 4.0

  def slows? = true

  def render(frame, camera_x = 0)
    cx = @x - camera_x + @w / 2
    cy = @y + @h / 2
    head = (frame.tick_count / TICKS_PER_SEGMENT).to_i % SEGMENTS
    SEGMENTS.times do |i|
      angle = i * 2 * Math::PI / SEGMENTS
      dist = (i - head) % SEGMENTS
      alpha = 235 - dist * (200 / SEGMENTS)
      frame.outputs.solids << {
        x: cx + Math.cos(angle) * RADIUS - SEG_W / 2,
        y: cy + Math.sin(angle) * RADIUS - SEG_H / 2,
        w: SEG_W, h: SEG_H,
        r: INK[0], g: INK[1], b: INK[2], a: alpha
      }
    end
  end
end
