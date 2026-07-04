class Hole
  W = 150 # narrower than a jump's ~320px reach, so every pit stays clearable
  COUNT = 4

  attr_accessor :x, :w

  def self.scatter(count: COUNT, world_w: WORLD_W, start_x: 700, end_margin: 700)
    slot = ((world_w - end_margin) - start_x) / count
    count.times.map do |i|
      x = start_x + i * slot + rand([ slot - W, 0 ].max)
      new(x: x, w: W)
    end
  end

  def initialize(x:, w:)
    @x = x
    @w = w
  end

  EDGE_W = 3

  def render(args, camera_x = 0)
    sx = @x - camera_x
    args.outputs.solids << { x: sx, y: 0, w: @w, h: GROUND_Y,
                             r: PAPER[0], g: PAPER[1], b: PAPER[2] }
    [ sx, sx + @w - EDGE_W ].each do |ex|
      args.outputs.solids << { x: ex, y: 0, w: EDGE_W, h: GROUND_Y,
                               r: INK[0], g: INK[1], b: INK[2] }
    end
  end
end
