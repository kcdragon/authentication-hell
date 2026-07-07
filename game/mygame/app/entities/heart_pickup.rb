class HeartPickup < Pickup
  SIZE = 28
  LIFT = 40
  SPRITE_NATIVE_W = 120
  SPRITE_NATIVE_H = 110

  def collect(player) = player.heal

  def render(frame, camera_x = 0, camera_y = 0)
    bob = bob_offset(frame.tick_count)
    sprite_h = @w * SPRITE_NATIVE_H / SPRITE_NATIVE_W
    frame.outputs.sprites << { x: @x - camera_x, y: @y + bob - camera_y, w: @w, h: sprite_h,
                              path: "sprites/ui/heart_hardmode.png" }
  end
end
