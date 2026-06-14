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

  # Brutalist "new-hire" figure, drawn from solid primitives inside the 64x96
  # hitbox (feet at @y): INK legs, an INK-bordered INDIGO torso (the platform card
  # treatment, so it sits in the same visual language), then a tan neck and head
  # with a hair band and two eyes that slide toward @facing. Geometry tuned here so
  # render stays readable; all dimensions are px within the hitbox, feet-up.
  BORDER     = 3
  LEG_H      = 14   # short INK leg blocks at the base
  LEG_W      = 18
  TORSO_H    = 46   # body card height, stacked above the legs
  NECK_H     = 4    # skin strip between torso and head
  NECK_W     = 12
  HEAD_H     = 30   # head block, stacked above the neck
  HEAD_INSET = 14   # head is narrower than the torso by this much each side
  HAIR_H     = 8    # hair band across the top of the face
  EYE        = 4    # small square eyes
  EYE_GAP    = 8    # space between the eyes
  FACE_SHIFT = 5    # how far the eyes slide toward @facing (0 when idle/:south)

  # Figure colors beyond the shared palette: a warm tan face and dark-brown hair.
  SKIN = [ 222, 184, 135 ]
  HAIR = [ 74, 52, 36 ]

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

  # Draw the figure as stacked brutalist primitives within the 64x96 hitbox: two
  # INK legs, an INK-bordered INDIGO torso (platform card treatment), a tan neck,
  # then a tan head with a dark hair band and two eyes that slide toward @facing as
  # the directional cue (centered when idle/:south). World x is shifted by the
  # camera offset to screen space.
  def render(args, camera_x = 0)
    sx = @x - camera_x

    leg_y   = @y
    torso_y = leg_y + LEG_H
    neck_y  = torso_y + TORSO_H
    head_y  = neck_y + NECK_H
    leg_gap = @w - 2 * LEG_W - 16
    args.outputs.solids << { x: sx + 8, y: leg_y, w: LEG_W, h: LEG_H, r: INK[0], g: INK[1], b: INK[2] }
    args.outputs.solids << { x: sx + 8 + LEG_W + leg_gap, y: leg_y, w: LEG_W, h: LEG_H,
                             r: INK[0], g: INK[1], b: INK[2] }

    card(args, sx, torso_y, @w, TORSO_H)
    args.outputs.solids << { x: sx + (@w - NECK_W) / 2, y: neck_y, w: NECK_W, h: NECK_H,
                             r: SKIN[0], g: SKIN[1], b: SKIN[2] }

    head_x = sx + HEAD_INSET
    head_w = @w - 2 * HEAD_INSET
    card(args, head_x, head_y, head_w, HEAD_H, SKIN)

    # Hair band across the top of the face, inside the ink border.
    args.outputs.solids << { x: head_x + BORDER, y: head_y + HEAD_H - BORDER - HAIR_H,
                             w: head_w - 2 * BORDER, h: HAIR_H, r: HAIR[0], g: HAIR[1], b: HAIR[2] }

    # Two eyes that slide toward @facing (centered when idle), the directional cue.
    shift = @facing == :west ? -FACE_SHIFT : (@facing == :east ? FACE_SHIFT : 0)
    eye_cx = sx + @w / 2
    [ eye_cx - EYE_GAP / 2 - EYE, eye_cx + EYE_GAP / 2 ].each do |ex|
      args.outputs.solids << { x: ex + shift, y: head_y + 10, w: EYE, h: EYE,
                               r: INK[0], g: INK[1], b: INK[2] }
    end

    # The keyboard slab (palette primitives): an INK body with a light CARD "keys"
    # strip on top so it reads as a keyboard. Tucked in hand when idle, thrust out
    # during a swing — keyboard_hitbox handles both.
    kb = keyboard_hitbox
    args.outputs.solids << { x: kb[:x] - camera_x, y: kb[:y], w: kb[:w], h: kb[:h],
                             r: INK[0], g: INK[1], b: INK[2] }
    args.outputs.solids << { x: kb[:x] - camera_x, y: kb[:y] + kb[:h] - 4,
                             w: kb[:w], h: 4, r: CARD[0], g: CARD[1], b: CARD[2] }
  end

  # A brutalist card like the platforms (entities/platform.rb): an INK rect with a
  # fill inset by BORDER (INDIGO by default; the head passes SKIN). Coords are
  # already screen-space.
  def card(args, x, y, w, h, fill = INDIGO)
    args.outputs.solids << { x: x, y: y, w: w, h: h, r: INK[0], g: INK[1], b: INK[2] }
    args.outputs.solids << { x: x + BORDER, y: y + BORDER, w: w - 2 * BORDER, h: h - 2 * BORDER,
                             r: fill[0], g: fill[1], b: fill[2] }
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
