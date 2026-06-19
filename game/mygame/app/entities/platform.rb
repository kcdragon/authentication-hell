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

  # A "desk/shelf" ledge drawn as a brutalist white card: an ink border, a white
  # face inset 3px, and an ink "underside" band flush below the face for built-in
  # thickness. The band is part of the object, so it scrolls with the platform —
  # no offset drop-shadow (which would crawl against the parallax). Border + band
  # use INDIGO to match the video chrome; the face stays neutral so the semantic
  # colors stay reserved for enemies/HUD.
  UNDERSIDE_H = 7

  def render(args, camera_x = 0)
    sx = @x - camera_x
    args.outputs.solids << { x: sx, y: @y - UNDERSIDE_H, w: @w, h: @h + UNDERSIDE_H,
                             r: INDIGO[0], g: INDIGO[1], b: INDIGO[2] }
    args.outputs.solids << { x: sx + 3, y: @y + 3, w: @w - 6, h: @h - 6,
                             r: CARD[0], g: CARD[1], b: CARD[2] }
  end

  # DragonRuby exports args.state for its dev tools; give it a plain-hash view (see
  # the same pattern on Enemy).
  def serialize = { x: @x, y: @y, w: @w, h: @h }
  def inspect = serialize.to_s
  def to_s = serialize.to_s
end
