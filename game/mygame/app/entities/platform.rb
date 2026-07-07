class Platform
  H = 30

  TIERS = [ 250, 330, 410 ]
  COUNT = 9
  STEP_DX = 180 # within a one-tier hop's reach, so every stacked step stays climbable

  attr_accessor :x, :y, :w, :h
  attr_reader :holds_password

  def self.scatter(count: COUNT)
    slot = (WORLD_W - 400) / count
    count.times.flat_map do |i|
      base_x = 200 + i * slot
      top = rand(TIERS.length)
      (0..top).map do |t|
        w = 180 + rand(100)
        new(x: base_x + t * STEP_DX, y: TIERS[t] - H, w: w, h: H, holds_password: t == top)
      end
    end
  end

  def initialize(x:, y:, w:, h:, holds_password: true)
    @x = x
    @y = y
    @w = w
    @h = h
    @holds_password = holds_password
  end

  UNDERSIDE_H = 7 # part of the platform rect, not an offset shadow — a shadow would crawl against scroll
  WORD_TICKS = [ 40, 24, 52, 30, 18 ].freeze

  def render(frame, camera_x = 0, camera_y = 0)
    sx = @x - camera_x
    sy = @y - camera_y
    frame.outputs.sprites << { path: :solid, x: sx, y: sy - UNDERSIDE_H, w: @w, h: @h + UNDERSIDE_H,
                             r: INK[0], g: INK[1], b: INK[2] }
    frame.outputs.sprites << { path: :solid, x: sx + 3, y: sy + 3, w: @w - 6, h: @h - 6,
                             r: INDIGO[0], g: INDIGO[1], b: INDIGO[2] }
    draw_caption(frame, sx, sy)
  end

  def on_collision(_other, _frame) = nil

  private

  def draw_caption(frame, sx, sy)
    frame.outputs.sprites << { path: :solid, x: sx + 8, y: sy + 6, w: 14, h: @h - 12,
                             r: BLUE[0], g: BLUE[1], b: BLUE[2] }
    cx = sx + 30
    word_y = sy + @h / 2 - 2
    WORD_TICKS.each do |ww|
      break if cx + ww > sx + @w - 10
      frame.outputs.sprites << { path: :solid, x: cx, y: word_y, w: ww, h: 5,
                               r: TS_INK[0], g: TS_INK[1], b: TS_INK[2] }
      cx += ww + 10
    end
  end
end
