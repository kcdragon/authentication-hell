# A collectable heart the player walks into to heal one heart. Owns its rect and
# rendering; pickup collision and the heal itself live in Main's tick. Smaller than
# the HUD hearts so it reads as a world item. Lives in args.state.collectables.
class HeartPickup
  SIZE = 28
  LIFT = 40 # px the heart floats above its base (ground or a platform top)
  BOB = 6 # px of vertical drift so it reads as a floating pickup

  attr_accessor :x, :y, :w, :h, :alive

  def initialize(x:, y:)
    @x = x
    @y = y
    @w = SIZE
    @h = SIZE
    @alive = true
  end

  def hitbox = { x: @x, y: @y, w: @w, h: @h }

  def render(args, camera_x = 0)
    bob = Math.sin(args.state.tick_count / 15.0) * BOB
    args.outputs.sprites << { x: @x - camera_x, y: @y + bob, w: @w, h: @h,
                              path: "sprites/ui/heart.png" }
  end

  # DragonRuby exports args.state for its dev tools; give it a plain-hash view (see
  # the same pattern on Enemy/Platform).
  def serialize = { x: @x, y: @y, w: @w, h: @h, alive: @alive }
  def inspect = serialize.to_s
  def to_s = serialize.to_s
end
