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

  def render(args, camera_x = 0)
    sx = @x - camera_x
    args.outputs.solids << { x: sx - STUB_W, y: @y - UNDERSIDE_H, w: STUB_W, h: @h + UNDERSIDE_H,
                             r: INK[0], g: INK[1], b: INK[2] }
    return if @w == 0

    args.outputs.solids << { x: sx, y: @y - UNDERSIDE_H, w: @w, h: @h + UNDERSIDE_H,
                             r: INK[0], g: INK[1], b: INK[2] }
    args.outputs.solids << { x: sx + 3, y: @y + 3, w: @w - 6, h: @h - 6,
                             r: TEAL[0], g: TEAL[1], b: TEAL[2] }
  end
end
