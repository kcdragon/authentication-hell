# An enemy that paces left/right within a patrol region: owns its own state,
# movement and rendering. Walking into one fires a re-auth flow (collision
# detection and the lock side effects live in tick). Lives in args.state.enemies.
class Enemy
  WIDTH = 64
  HEIGHT = 96
  PATROL_RANGE = 220 # half-width of the patrol span around the spawn x

  # Each auth kind colors its enemy: TOTP purple, passkey blue, password amber.
  AUTH_COLORS = {
    totp: { r: 90, g: 60, b: 160 },
    passkey: { r: 60, g: 120, b: 200 },
    password: { r: 200, g: 140, b: 40 }
  }

  attr_accessor :x, :y, :w, :h, :alive, :colliding, :auth, :r, :g, :b,
                :vx, :patrol_min_x, :patrol_max_x

  # Two enemies of each auth kind, scattered across the world: one per evenly
  # spaced slot (so they spread out) starting well past the player's spawn, each
  # at a random x within its slot.
  def self.spawn_random
    auths = [ :totp, :totp, :passkey, :passkey, :password, :password ].shuffle
    start = 800
    slot = (WORLD_W - start - WIDTH) / auths.length
    auths.map.with_index do |auth, i|
      new(x: start + i * slot + rand([ slot - WIDTH, 0 ].max), auth: auth)
    end
  end

  def initialize(x:, auth:)
    @x = x
    @y = GROUND_Y
    @w = WIDTH
    @h = HEIGHT
    @auth = auth
    @alive = true
    @colliding = false
    @patrol_min_x = @x - PATROL_RANGE
    @patrol_max_x = @x + PATROL_RANGE
    @vx = [ -1, 1 ].sample * (1 + rand(2)) # 1–2 px/frame, random direction
    color = AUTH_COLORS[auth]
    @r = color[:r]
    @g = color[:g]
    @b = color[:b]
  end

  # Pace horizontally within the patrol bounds, reversing at each edge. Clamp to
  # the bound before flipping so a fast step can't drift past the region.
  def update
    @x += @vx
    if @x <= @patrol_min_x
      @x = @patrol_min_x
      @vx = @vx.abs
    elsif @x >= @patrol_max_x
      @x = @patrol_max_x
      @vx = -@vx.abs
    end
  end

  def render(args, camera_x = 0)
    args.outputs.solids << { x: @x - camera_x, y: @y, w: @w, h: @h, r: @r, g: @g, b: @b }
  end

  # DragonRuby exports args.state for its dev tools; a plain object without a
  # serialize method can choke that export (see the http-handle nils in main.rb).
  def serialize
    { x: @x, y: @y, w: @w, h: @h, auth: @auth, alive: @alive,
      colliding: @colliding, r: @r, g: @g, b: @b, vx: @vx,
      patrol_min_x: @patrol_min_x, patrol_max_x: @patrol_max_x }
  end

  def inspect = serialize.to_s
  def to_s = serialize.to_s
end
