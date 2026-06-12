# A stationary enemy: owns its own state and rendering. Walking into one fires a
# re-auth flow (collision detection and the lock side effects live in tick).
# Lives in args.state.enemies.
class Enemy
  WIDTH = 64
  HEIGHT = 96

  # Each auth kind colors its enemy: TOTP purple, passkey blue, password amber.
  AUTH_COLORS = {
    totp: { r: 90, g: 60, b: 160 },
    passkey: { r: 60, g: 120, b: 200 },
    password: { r: 200, g: 140, b: 40 }
  }

  attr_accessor :x, :y, :w, :h, :alive, :colliding, :auth, :r, :g, :b

  # The three enemies, spaced so none overlaps the player's centered spawn:
  # passkey on the left, password right-of-center, TOTP on the right.
  def self.spawn_defaults
    [
      new(x: SCREEN_W - WIDTH - 120, auth: :totp),
      new(x: 120, auth: :passkey),
      new(x: (SCREEN_W - WIDTH) / 2 + 240, auth: :password)
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
