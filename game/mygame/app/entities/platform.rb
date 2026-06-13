# A one-way ledge the player can land on from below: owns its rect and rendering,
# plus the shared layout constants and a factory so any level can build a scattered
# field of them. Lives in args.state.platforms; landing collision is in
# Player#update (it reads x/y/w/h duck-typed).
class Platform
  H = 30

  # Reachable one-way ledge tops: ~290px apex from the ground reaches the low
  # tier; the higher tiers are reachable by hopping up off a lower ledge.
  TIERS = [ 250, 330, 410 ]
  COUNT = 9

  attr_accessor :x, :y, :w, :h

  # Scatter `count` one-way ledges across the world, one per evenly spaced slot (so
  # they spread out instead of clumping) with a random width and a random reachable
  # tier height. Generated once per level.
  def self.scatter(count: COUNT)
    slot = (WORLD_W - 400) / count
    count.times.map do |i|
      w = 180 + rand(100)
      x = 200 + i * slot + rand([ slot - w, 0 ].max)
      new(x: x, y: TIERS.sample - H, w: w, h: H)
    end
  end

  def initialize(x:, y:, w:, h:)
    @x = x
    @y = y
    @w = w
    @h = h
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
