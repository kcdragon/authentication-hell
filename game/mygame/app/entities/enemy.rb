# A stationary enemy: owns its own state and rendering. Walking into one fires a
# re-auth flow (collision detection and the lock side effects live in tick).
# Lives in args.state.enemies.
class Enemy
  WIDTH = 64
  HEIGHT = 96

  # Each auth kind colors its enemy: TOTP purple, passkey blue.
  AUTH_COLORS = {
    totp: { r: 90, g: 60, b: 160 },
    passkey: { r: 60, g: 120, b: 200 }
  }

  attr_accessor :x, :y, :w, :h, :alive, :colliding, :auth, :r, :g, :b

  # The two enemies parked off to each side: TOTP on the right, passkey on the left.
  def self.spawn_defaults
    [
      new(x: SCREEN_W - WIDTH - 120, auth: :totp),
      new(x: 120, auth: :passkey)
    ]
  end

  def initialize(x:, auth:)
    @x = x
    @y = GROUND_Y
    @w = WIDTH
    @h = HEIGHT
    @auth = auth
    @alive = true
    @colliding = false
    color = AUTH_COLORS[auth]
    @r = color[:r]
    @g = color[:g]
    @b = color[:b]
  end

  def render(args)
    args.outputs.solids << { x: @x, y: @y, w: @w, h: @h, r: @r, g: @g, b: @b }
  end

  # DragonRuby exports args.state for its dev tools; a plain object without a
  # serialize method can choke that export (see the http-handle nils in main.rb).
  def serialize
    { x: @x, y: @y, w: @w, h: @h, auth: @auth, alive: @alive,
      colliding: @colliding, r: @r, g: @g, b: @b }
  end

  def inspect = serialize.to_s
  def to_s = serialize.to_s
end
