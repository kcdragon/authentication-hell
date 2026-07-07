class RubyPickup < Pickup
  SIZE = 44
  LIFT = 20

  def render(frame, camera_x = 0, camera_y = 0)
    bob = bob_offset(frame.tick_count)
    frame.outputs.sprites << { x: @x - camera_x, y: @y + bob - camera_y, w: @w, h: @h,
                              path: "sprites/ui/ruby.png" }
  end
end
