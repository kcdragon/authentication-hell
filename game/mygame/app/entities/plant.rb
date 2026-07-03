class Plant
  KINDS = {
    coreopsis: { path: "sprites/plants/coreopsis.png", w: 107, h: 165 },
    pink_bush: { path: "sprites/plants/pink-bush.png", w: 120, h: 112 },
    poppy_bush: { path: "sprites/plants/poppy-bush.png", w: 157, h: 140 }
  }.freeze

  attr_reader :x, :y, :w, :h, :path

  def initialize(x:, kind:, y: GROUND_Y, scale: 1.0)
    spec = KINDS.fetch(kind)
    @x = x
    @y = y
    @path = spec[:path]
    @w = (spec[:w] * scale).to_i
    @h = (spec[:h] * scale).to_i
  end

  def render(args, camera_x = 0)
    args.outputs.sprites << { x: @x - camera_x, y: @y, w: @w, h: @h, path: @path }
  end

  def serialize = { x: @x, y: @y, w: @w, h: @h, path: @path }
  def inspect = serialize.to_s
  def to_s = serialize.to_s
end
