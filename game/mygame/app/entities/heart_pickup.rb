# A collectable heart the player walks into to heal one heart, smaller than the HUD
# hearts so it reads as a world item.
class HeartPickup
  include Collectable

  SIZE = 28
  LIFT = 40 # px the heart floats above its base (ground or a platform top)
  BOB = 6 # px of vertical drift so it reads as a floating pickup

  attr_accessor :x, :y, :w, :h

  def initialize(x:, y:)
    @x = x
    @y = y
    @w = SIZE
    @h = SIZE
    @alive = true
  end

  def hitbox = { x: @x, y: @y, w: @w, h: @h }

  def collect(player) = player.heal

  def render(args, camera_x = 0)
    bob = Math.sin(args.state.tick_count / 15.0) * BOB
    # Draw the HUD heart sprite (120x110) at the pickup's width, keeping its aspect
    # ratio so it isn't squished into the square hitbox.
    sprite_h = @w * 110 / 120
    args.outputs.sprites << { x: @x - camera_x, y: @y + bob, w: @w, h: sprite_h,
                              path: "sprites/ui/heart_hardmode.png" }
  end

  # DragonRuby exports args.state for its dev tools; give it a plain-hash view (see
  # the same pattern on Enemy/Platform).
  def serialize = { x: @x, y: @y, w: @w, h: @h, alive: @alive }
  def inspect = serialize.to_s
  def to_s = serialize.to_s
end
