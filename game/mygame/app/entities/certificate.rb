# A certificate of completion — each level's goal, finished by walking into it (the
# level latches completion off the retired certificate).
class Certificate
  include Collectable

  SIZE = 60
  LIFT = 30 # px the certificate floats above its surface
  BOB = 6 # px of vertical drift so it reads as a floating pickup

  attr_accessor :x, :y, :w, :h

  def initialize(x:, y: GROUND_Y)
    @x = x
    @y = y + LIFT
    @w = SIZE
    @h = SIZE
    @alive = true
  end

  def hitbox = { x: @x, y: @y, w: @w, h: @h }

  def collect(_player) = nil

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
