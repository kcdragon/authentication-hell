# A one-way ledge the player can land on from below: owns its rect and rendering,
# plus the shared layout constants and a factory so any level can build a scattered
# field of them. Lives in args.state.platforms; landing collision is in
# Player#update (it reads x/y/w/h duck-typed).
class Platform
  H = 30

  # One-way ledge tops: only the low tier is reachable from the ground; higher tiers
  # need a hop up off a lower ledge (see #scatter).
  TIERS = [ 250, 330, 410 ]
  COUNT = 9
  STEP_DX = 180 # horizontal stagger between stacked steps (inside a one-tier hop's reach)

  attr_accessor :x, :y, :w, :h
  attr_reader :holds_password

  # One staircase per evenly spaced slot, climbing from the low tier to a random target
  # tier — each step a single hop above the one below, so every ledge is reachable. Only
  # the top step holds a padlock; the rest are bare footholds.
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

  # A ledge drawn as the video's closed-caption bar: an ink border with an ink
  # "underside" band flush below for built-in thickness (part of the object, so it
  # scrolls with the platform — no offset drop-shadow that would crawl against the
  # parallax), a dark INDIGO caption face inset 3px, a BLUE "CC" indicator tab, and
  # light "subtitle word" ticks across the face. The dark face keeps the semantic
  # colors reserved for enemies/HUD.
  UNDERSIDE_H = 7
  WORD_TICKS = [ 40, 24, 52, 30, 18 ].freeze # subtitle "word" widths, drawn until the face runs out

  def render(args, camera_x = 0)
    sx = @x - camera_x
    args.outputs.solids << { x: sx, y: @y - UNDERSIDE_H, w: @w, h: @h + UNDERSIDE_H,
                             r: INK[0], g: INK[1], b: INK[2] }
    args.outputs.solids << { x: sx + 3, y: @y + 3, w: @w - 6, h: @h - 6,
                             r: INDIGO[0], g: INDIGO[1], b: INDIGO[2] }
    draw_caption(args, sx)
  end

  private

  def draw_caption(args, sx)
    args.outputs.solids << { x: sx + 8, y: @y + 6, w: 14, h: @h - 12,
                             r: BLUE[0], g: BLUE[1], b: BLUE[2] }
    cx = sx + 30
    word_y = @y + @h / 2 - 2
    WORD_TICKS.each do |ww|
      break if cx + ww > sx + @w - 10
      args.outputs.solids << { x: cx, y: word_y, w: ww, h: 5,
                               r: TS_INK[0], g: TS_INK[1], b: TS_INK[2] }
      cx += ww + 10
    end
  end

  public

  # DragonRuby exports args.state for its dev tools; give it a plain-hash view (see
  # the same pattern on Enemy).
  def serialize = { x: @x, y: @y, w: @w, h: @h }
  def inspect = serialize.to_s
  def to_s = serialize.to_s
end
