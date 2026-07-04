class HeartPickup
  include Collectable

  SIZE = 28
  LIFT = 40
  BOB = 6
  SPRITE_NATIVE_W = 120
  SPRITE_NATIVE_H = 110

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
    bob = bob_offset(args.state.tick_count)
    sprite_h = @w * SPRITE_NATIVE_H / SPRITE_NATIVE_W
    args.outputs.sprites << { x: @x - camera_x, y: @y + bob, w: @w, h: sprite_h,
                              path: "sprites/ui/heart_hardmode.png" }
  end
end
