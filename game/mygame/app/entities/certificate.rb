class Certificate < Pickup
  SIZE = 60
  LIFT = 30

  def initialize(x:, y: GROUND_Y)
    super(x: x, y: y + LIFT)
  end

  def render(frame, camera_x = 0, camera_y = 0)
    bob = bob_offset(frame.tick_count)
    frame.outputs.sprites << { x: @x - camera_x, y: @y + bob - camera_y, w: @w, h: @h,
                              path: "sprites/ui/certificate.png" }
  end
end
