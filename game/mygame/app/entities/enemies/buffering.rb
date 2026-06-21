# The buffering spinner: a loading-wheel enemy that paces like the others. Unlike the
# auth enemies, a side hit doesn't dock a heart or fire re-auth — it just lags the
# player for a few seconds (a "still buffering…" slowdown). Stomping it still defeats
# it cleanly. Drawn as a rotating comet of segments instead of a sprite.
class BufferingEnemy < Enemy
  AUTH = nil # never re-auths — see #slows? (contact slows the player instead)
  COLOR = { r: MUTED[0], g: MUTED[1], b: MUTED[2] }

  # Spinner geometry (drawn as a rotating arc of fading segments). SPIN_DIVISOR
  # scales tick_count to the rotation (smaller = faster spin).
  RADIUS = 26
  SEGMENTS = 12
  SEG_W = 8
  SEG_H = 5
  SPIN_DIVISOR = 4.0

  def slows? = true

  # A couple of spinners spread across the world past the player's safe gap (mirrors
  # Enemy.spawn_random's start), so they never load already touching the player.
  def self.scatter(player_x, count: 2)
    start = [ player_x + SAFE_GAP, 1200 ].max
    slot = (WORLD_W - start - WIDTH) / count
    count.times.map do |i|
      new(x: start + i * slot + rand([ slot - WIDTH, 0 ].max))
    end
  end

  # A ring of segments with one bright "head" that rotates each tick, trailing into a
  # faint tail — the classic buffering spinner. Centered in the body footprint.
  def render(args, camera_x = 0)
    cx = @x - camera_x + @w / 2
    cy = @y + @h / 2
    head = (args.state.tick_count / SPIN_DIVISOR).to_i % SEGMENTS
    SEGMENTS.times do |i|
      angle = i * 2 * Math::PI / SEGMENTS
      dist = (i - head) % SEGMENTS
      alpha = 235 - dist * (200 / SEGMENTS)
      args.outputs.solids << {
        x: cx + Math.cos(angle) * RADIUS - SEG_W / 2,
        y: cy + Math.sin(angle) * RADIUS - SEG_H / 2,
        w: SEG_W, h: SEG_H,
        r: INK[0], g: INK[1], b: INK[2], a: alpha
      }
    end
  end
end
