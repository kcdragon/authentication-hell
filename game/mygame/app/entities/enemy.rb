# Abstract base for the auth enemies: paces left/right within a patrol region and
# owns its state, movement and rendering. Walking into one fires a re-auth flow
# (collision detection and the lock side effects live in tick). Each concrete kind
# is a subclass under entities/enemies/ declaring its AUTH and COLOR; they live in
# args.state.enemies. Never instantiated directly.
class Enemy
  WIDTH = 64
  HEIGHT = 96
  PATROL_RANGE = 220 # half-width of the patrol span around the spawn x
  # Clearance ahead of the player so the nearest enemy's patrol never reaches it.
  SAFE_GAP = PATROL_RANGE + WIDTH + 64

  attr_accessor :x, :y, :w, :h, :alive, :colliding, :auth, :r, :g, :b,
                :vx, :patrol_min_x, :patrol_max_x

  # Two of each kind, scattered across the world: one per evenly spaced slot (so
  # they spread out) starting a safe gap to the right of the player (who carries
  # their position over from the welcome level) so none can collide on load, each at a
  # random x within its slot. Listed here (not a constant) so the subclasses —
  # required after this file — are already defined when spawn runs.
  def self.spawn_random(player_x)
    kinds = [ TotpEnemy, TotpEnemy, PasskeyEnemy, PasskeyEnemy, PasswordEnemy, PasswordEnemy ].shuffle
    start = [ player_x + SAFE_GAP, 800 ].max
    slot = (WORLD_W - start - WIDTH) / kinds.length
    kinds.map.with_index do |kind, i|
      x = start + i * slot + rand([ slot - WIDTH, 0 ].max)
      kind.new(x: x)
    end
  end

  def initialize(x:)
    @x = x
    @y = GROUND_Y
    @w = WIDTH
    @h = HEIGHT
    @auth = self.class::AUTH
    @alive = true
    @colliding = false
    @patrol_min_x = @x - PATROL_RANGE
    @patrol_max_x = @x + PATROL_RANGE
    @vx = [ -1, 1 ].sample * (1 + rand(2)) # 1–2 px/frame, random direction
    color = self.class::COLOR
    @r = color[:r]
    @g = color[:g]
    @b = color[:b]
  end

  # Reconfigure this enemy to march left from its current x, patrolling the full
  # width to its left (the welcome level uses this to walk it in from the right screen
  # edge). It still patrols, so if it's never touched it turns around at the far
  # left and comes back.
  def march_left(speed)
    @vx = -speed
    @patrol_max_x = @x
    @patrol_min_x = -@w
  end

  # Mirror of #march_left: march right from the current x, patrolling to `max` on
  # its right (the welcome level uses this to walk it in from the left screen edge, and
  # caps max at the one-screen world so it can't escape). It still patrols, turning
  # around at the far edge if never touched.
  def march_right(speed, max: WORLD_W)
    @vx = speed
    @patrol_min_x = @x
    @patrol_max_x = max
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

  # Collision rect. Defaults to the full body; subclasses with a visual smaller
  # than their footprint (see PasswordEnemy) inset this to match what's drawn.
  def hitbox
    { x: @x, y: @y, w: @w, h: @h }
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
