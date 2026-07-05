class Plant
  KINDS = {
    coreopsis: { path: "sprites/plants/coreopsis.png", w: 107, h: 165 },
    pink_bush: { path: "sprites/plants/pink-bush.png", w: 134, h: 98 },
    poppy_bush: { path: "sprites/plants/poppy-bush.png", w: 152, h: 140 }
  }.freeze

  # Lower the sprites a bit so the plant appears to be on the ground
  ROOT_SINK = 10

  attr_reader :x, :y, :w, :h, :path

  def initialize(x:, kind:, y: GROUND_Y, scale: 1.0)
    spec = KINDS.fetch(kind)
    @x = x
    @y = y
    @path = spec[:path]
    @w = (spec[:w] * scale).to_i
    @h = (spec[:h] * scale).to_i
  end

  def render(frame, camera_x = 0)
    frame.outputs.sprites << { x: @x - camera_x, y: @y - ROOT_SINK, w: @w, h: @h, path: @path }
  end
end
