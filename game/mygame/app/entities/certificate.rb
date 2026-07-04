class Certificate
  include Collectable

  SIZE = 60
  LIFT = 30
  BOB = 6

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
    bob = bob_offset(args.state.tick_count)
    args.outputs.sprites << { x: @x - camera_x, y: @y + bob, w: @w, h: @h,
                              path: "sprites/ui/certificate.png" }
  end
end
