# A certificate of completion — each level's goal. Walking into it finishes the
# level, replacing the old "reach the right wall" trigger. There's no per-player
# effect: the level latches completion off the retired certificate (alive: false),
# so #collect is a no-op. Pickup collision lives in Main's tick, like the other
# collectables; lives on the level's collectables.
class Certificate
  SIZE = 60
  LIFT = 30 # px the certificate floats above its surface
  BOB = 6 # px of vertical drift so it reads as a floating pickup

  attr_accessor :x, :y, :w, :h, :alive

  def initialize(x:, y: GROUND_Y)
    @x = x
    @y = y + LIFT
    @w = SIZE
    @h = SIZE
    @alive = true
  end

  def hitbox = { x: @x, y: @y, w: @w, h: @h }

  # Walked into: nothing to apply — the level detects the consumed certificate
  # (alive flipped false by the pickup loop) to latch completion.
  def collect(args) = nil

  def render(args, camera_x = 0)
    bob = Math.sin(args.state.tick_count / 15.0) * BOB
    args.outputs.sprites << { x: @x - camera_x, y: @y + bob, w: @w, h: @h,
                              path: "sprites/ui/certificate.png" }
  end

  # DragonRuby exports args.state for its dev tools; give it a plain-hash view (see
  # the same pattern on HeartPickup/PasswordCharacter).
  def serialize = { x: @x, y: @y, w: @w, h: @h, alive: @alive }
  def inspect = serialize.to_s
  def to_s = serialize.to_s
end
