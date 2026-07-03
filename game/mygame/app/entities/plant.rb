class Plant
  KINDS = {
    coreopsis: { path: "sprites/plants/coreopsis.png", w: 107, h: 165 },
    pink_bush: { path: "sprites/plants/pink-bush.png", w: 120, h: 112 },
    poppy_bush: { path: "sprites/plants/poppy-bush.png", w: 157, h: 140 }
  }.freeze

  attr_reader :x, :w, :h, :path

  def initialize(x:, kind:)
    spec = KINDS.fetch(kind)
    @x = x
    @path = spec[:path]
    @w = spec[:w]
    @h = spec[:h]
  end

  def render(args, camera_x = 0)
    args.outputs.sprites << { x: @x - camera_x, y: GROUND_Y, w: @w, h: @h, path: @path }
  end

  def serialize = { x: @x, w: @w, h: @h, path: @path }
  def inspect = serialize.to_s
  def to_s = serialize.to_s
end
