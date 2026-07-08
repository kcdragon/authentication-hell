class Enemy
  WIDTH = 64
  HEIGHT = 96
  PATROL_RANGE = 220
  SAFE_GAP = PATROL_RANGE + WIDTH + 64

  attr_reader :x, :y, :w, :h, :auth, :vx, :patrol_min_x, :patrol_max_x
  attr_accessor :alive

  def initialize(x:, level:, y: GROUND_Y)
    @x = x
    @y = y
    @w = WIDTH
    @h = HEIGHT
    @auth = self.class::AUTH
    @alive = true
    @level = level
    @patrol_min_x = @x - PATROL_RANGE
    @patrol_max_x = @x + PATROL_RANGE
    @vx = [ -1, 1 ].sample * (1 + rand(2))
    color = self.class::COLOR
    @r = color[:r]
    @g = color[:g]
    @b = color[:b]
  end

  def march_left(speed)
    @vx = -speed
    @patrol_max_x = @x
    @patrol_min_x = -@w
  end

  def march_right(speed, max: WORLD_W)
    @vx = speed
    @patrol_min_x = @x
    @patrol_max_x = max
  end

  def patrol_on(platform)
    @y = platform.y + platform.h
    @patrol_min_x = platform.x
    @patrol_max_x = platform.x + platform.w - @w
    @x = @x.clamp(@patrol_min_x, @patrol_max_x)
    self
  end

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

  def hitbox
    { x: @x, y: @y, w: @w, h: @h }
  end

  def on_collision(other, frame)
    return unless other.is_a?(Player)

    if stompable? && other.stomping?(self)
      die
    elsif slows?
      die
    elsif !other.invincible?(frame)
      die
    end
  end

  def stompable? = true

  def slows? = false

  def render(frame, camera_x = 0, camera_y = 0)
    frame.outputs.sprites << { path: :solid, x: @x - camera_x, y: @y - camera_y, w: @w, h: @h, r: @r, g: @g, b: @b }
  end

  private

  def die
    @alive = false
    @level.drop_loot(self)
  end
end
