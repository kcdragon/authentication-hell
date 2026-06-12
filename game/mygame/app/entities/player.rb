# The player character: owns its own state, input-driven movement (simple
# platformer physics), and rendering. Lives in args.state.player.
class Player
  WIDTH = 64
  HEIGHT = 96
  MOVE_SPEED = 8
  JUMP_SPEED = 20
  GRAVITY = 1
  MAX_HEARTS = 3

  # The character art fills only a sub-rectangle of each 64x64 sprite frame (the
  # rest is transparent padding); SPRITE_CROP_* bounds it (cols 24..39, rows
  # ending at the feet, measured bottom-up) so the crop can stand on the ground
  # instead of floating on its padding.
  SPRITE_CROP_X = 24
  SPRITE_CROP_Y = 17
  SPRITE_CROP_W = 16
  SPRITE_CROP_H = 31

  attr_accessor :x, :y, :w, :h, :vy, :grounded, :facing,
                :locked, :colliding, :lock_confirmed, :pending_challenge,
                :hearts, :game_over

  def initialize
    @x = (SCREEN_W - WIDTH) / 2
    @y = GROUND_Y
    @w = WIDTH
    @h = HEIGHT
    @vy = 0
    @grounded = true
    @facing = :south
    @locked = false
    @colliding = false
    @lock_confirmed = false
    @pending_challenge = nil
    @hearts = MAX_HEARTS
    @game_over = false
  end

  # Move left/right with the arrow keys (no wrapping — clamp to screen); space
  # jumps when grounded. Frozen while locked, until the player re-authenticates.
  def update(args)
    return if @locked || @game_over

    if args.inputs.keyboard.left
      @x -= MOVE_SPEED
      @facing = :west
    elsif args.inputs.keyboard.right
      @x += MOVE_SPEED
      @facing = :east
    else
      @facing = :south
    end

    @x = @x.clamp(0, SCREEN_W - WIDTH)

    # Jump on the press edge so holding space doesn't re-launch every frame.
    if args.inputs.keyboard.key_down.space && @grounded
      @vy = JUMP_SPEED
      @grounded = false
    end

    @vy -= GRAVITY
    prev_y = @y
    @y += @vy

    @grounded = false
    if @y <= GROUND_Y
      @y = GROUND_Y
      @vy = 0
      @grounded = true
    elsif @vy <= 0
      # One-way platforms: land only while descending and only if the player's
      # bottom crossed the platform's top this frame (so you pass up through it).
      PLATFORMS.each do |plat|
        top = plat.y + plat.h
        horizontal = @x + @w > plat.x && @x < plat.x + plat.w
        if horizontal && prev_y >= top && @y <= top
          @y = top
          @vy = 0
          @grounded = true
          break
        end
      end
    end
  end

  # Draw just the character (cropped from its padded frame) hitbox-tall and
  # centered over the 64x96 hitbox, anchored at y so its feet meet the ground.
  # Facing follows movement, south (facing the camera) when idle.
  def render(args)
    sprite_h = @h
    sprite_w = sprite_h * SPRITE_CROP_W / SPRITE_CROP_H
    args.outputs.sprites << { x: @x + (@w - sprite_w) / 2,
                              y: @y,
                              w: sprite_w,
                              h: sprite_h,
                              source_x: SPRITE_CROP_X,
                              source_y: SPRITE_CROP_Y,
                              source_w: SPRITE_CROP_W,
                              source_h: SPRITE_CROP_H,
                              path: "sprites/player/#{@facing}.png" }
  end

  # DragonRuby exports args.state for its dev tools; a plain object without a
  # serialize method can choke that export (see the http-handle nils in main.rb).
  def serialize
    { x: @x, y: @y, w: @w, h: @h, vy: @vy, grounded: @grounded, facing: @facing,
      locked: @locked, colliding: @colliding, lock_confirmed: @lock_confirmed,
      pending_challenge: @pending_challenge, hearts: @hearts, game_over: @game_over }
  end

  def inspect = serialize.to_s
  def to_s = serialize.to_s
end
