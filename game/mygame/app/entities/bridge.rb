class Bridge < Platform
  EXTEND_SPEED = 16
  STUB_W = 14

  def initialize(x:, span:)
    super(x: x, y: GROUND_Y - Platform::H, w: 0, h: Platform::H, holds_password: false)
    @span = span
    @opening = false
  end

  def open!
    @opening = true
  end

  def update
    return unless @opening

    @w = [ @w + EXTEND_SPEED, @span ].min
  end

  def extended? = @w >= @span

  def render(frame, camera_x = 0, camera_y = 0)
    sx = @x - camera_x
    sy = @y - camera_y
    frame.outputs.sprites << { path: :solid, x: sx - STUB_W, y: sy - UNDERSIDE_H, w: STUB_W, h: @h + UNDERSIDE_H,
                             r: INK[0], g: INK[1], b: INK[2] }
    return if @w == 0

    frame.outputs.sprites << { path: :solid, x: sx, y: sy - UNDERSIDE_H, w: @w, h: @h + UNDERSIDE_H,
                             r: INK[0], g: INK[1], b: INK[2] }
    frame.outputs.sprites << { path: :solid, x: sx + 3, y: sy + 3, w: @w - 6, h: @h - 6,
                             r: TEAL[0], g: TEAL[1], b: TEAL[2] }
  end
end
