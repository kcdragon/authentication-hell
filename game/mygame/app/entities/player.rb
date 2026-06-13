# The player character: owns its own state, input-driven movement (simple
# platformer physics), and rendering. Lives in args.state.player.
class Player
  WIDTH = 64
  HEIGHT = 96
  MOVE_SPEED = 8
  JUMP_SPEED = 20
  GRAVITY = 1
  MAX_HEARTS = 3

  # Keyboard melee weapon: a wide flat slab held at hand height in front of the
  # player. A click swings it for SWING_TICKS frames (which is also the cooldown —
  # no new swing until the current one finishes); REACH eases from held to apex.
  KEYBOARD_W = 76
  KEYBOARD_H = 28
  KEYBOARD_HAND_Y = 36       # px above @y (feet) — hand height
  KEYBOARD_GRIP = 8          # px the inner edge overlaps the hand (the rest sticks out)
  KEYBOARD_SWING_REACH = 40  # extra outward thrust at the swing's apex
  SWING_TICKS = 12           # swing duration = cooldown

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
                :hearts, :game_over, :swing_ticks_left, :swing_dir, :moved,
                :reached_platform

  def initialize
    @x = 200            # near the left of the world; the scene extends right
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
    @swing_ticks_left = 0
    @swing_dir = :east
    @moved = false
    @reached_platform = false
  end

  # Move left/right with the arrow keys (no wrapping — clamp to screen); space
  # jumps when grounded. Frozen while locked, until the player re-authenticates.
  def update(args)
    return if @locked || @game_over

    # Tick down any in-progress swing; the keyboard is "live" while > 0, and a new
    # swing can't start until it reaches 0 (the duration is the cooldown).
    @swing_ticks_left -= 1 if @swing_ticks_left.positive?

    # @swing_dir tracks movement so the held keyboard flips the instant the player
    # turns, not only when they swing. Idle (:south) leaves it on the last side.
    if args.inputs.keyboard.left
      @x -= MOVE_SPEED
      @facing = :west
      @swing_dir = :west
      @moved = true
    elsif args.inputs.keyboard.right
      @x += MOVE_SPEED
      @facing = :east
      @swing_dir = :east
      @moved = true
    else
      @facing = :south
    end

    @x = @x.clamp(0, WORLD_W - WIDTH)

    # Left-click swings the keyboard; it points whichever way @swing_dir already
    # holds (the last side the player faced).
    if args.inputs.mouse.click && @swing_ticks_left.zero?
      @swing_ticks_left = SWING_TICKS
    end

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
      args.state.platforms.each do |plat|
        top = plat.y + plat.h
        horizontal = @x + @w > plat.x && @x < plat.x + plat.w
        if horizontal && prev_y >= top && @y <= top
          @y = top
          @vy = 0
          @grounded = true
          @reached_platform = true
          break
        end
      end
    end
  end

  # World-space rect for the keyboard, sticking out from the hand on @swing_dir
  # side: its inner edge grips the player's side (overlapping by GRIP) and the slab
  # extends outward, away from the body. A swing thrusts it further out, eased
  # out-and-back (sin peaks mid-swing); at rest thrust is 0, so the same rect
  # serves both the idle render and the swing hitbox.
  def keyboard_hitbox
    progress = @swing_ticks_left.to_f / SWING_TICKS
    thrust = KEYBOARD_SWING_REACH * Math.sin(progress * Math::PI)
    hand_y = @y + KEYBOARD_HAND_Y
    if @swing_dir == :west
      inner = @x + KEYBOARD_GRIP - thrust          # right edge near the left hand
      { x: inner - KEYBOARD_W, y: hand_y, w: KEYBOARD_W, h: KEYBOARD_H }
    else
      inner = @x + @w - KEYBOARD_GRIP + thrust      # left edge near the right hand
      { x: inner, y: hand_y, w: KEYBOARD_W, h: KEYBOARD_H }
    end
  end

  # Draw just the character (cropped from its padded frame) hitbox-tall and
  # centered over the 64x96 hitbox, anchored at y so its feet meet the ground.
  # Facing follows movement, south (facing the camera) when idle. World x is
  # shifted by the camera offset to screen space.
  def render(args, camera_x = 0)
    sprite_h = @h
    sprite_w = sprite_h * SPRITE_CROP_W / SPRITE_CROP_H
    args.outputs.sprites << { x: @x - camera_x + (@w - sprite_w) / 2,
                              y: @y,
                              w: sprite_w,
                              h: sprite_h,
                              source_x: SPRITE_CROP_X,
                              source_y: SPRITE_CROP_Y,
                              source_w: SPRITE_CROP_W,
                              source_h: SPRITE_CROP_H,
                              path: "sprites/player/#{@facing}.png" }

    # The keyboard slab (solid primitives, matching the enemies' style): a dark
    # body with a lighter top edge so it reads as a keyboard. Tucked in hand when
    # idle, thrust out during a swing — keyboard_hitbox handles both.
    kb = keyboard_hitbox
    args.outputs.solids << { x: kb[:x] - camera_x, y: kb[:y], w: kb[:w], h: kb[:h],
                             r: 60, g: 60, b: 70 }
    args.outputs.solids << { x: kb[:x] - camera_x, y: kb[:y] + kb[:h] - 4,
                             w: kb[:w], h: 4, r: 150, g: 150, b: 160 }
  end

  # DragonRuby exports args.state for its dev tools; a plain object without a
  # serialize method can choke that export (see the http-handle nils in main.rb).
  def serialize
    { x: @x, y: @y, w: @w, h: @h, vy: @vy, grounded: @grounded, facing: @facing,
      locked: @locked, colliding: @colliding, lock_confirmed: @lock_confirmed,
      pending_challenge: @pending_challenge, hearts: @hearts, game_over: @game_over,
      swing_ticks_left: @swing_ticks_left, swing_dir: @swing_dir, moved: @moved,
      reached_platform: @reached_platform }
  end

  def inspect = serialize.to_s
  def to_s = serialize.to_s
end
