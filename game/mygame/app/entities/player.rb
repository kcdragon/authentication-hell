# The player character: owns its own state, input-driven movement (simple
# platformer physics), and rendering. Lives in args.state.player.
class Player
  WIDTH = 64
  HEIGHT = 96
  MOVE_SPEED = 8
  SLOW_MOVE_SPEED = 3  # crawl speed while a buffering enemy is lagging the player
  SLOW_TICKS = 180     # how long that lag lasts (~3s at 60fps)
  JUMP_SPEED = 20
  STOMP_BOUNCE = 12  # small hop after stomping an enemy (less than a full jump)
  GRAVITY = 1
  MAX_HEARTS = 3
  BLINK_TICKS = 60     # how long the figure flickers after a hit (~1s at 60fps)
  BLINK_INTERVAL = 4   # toggle visibility every 4 ticks (~7-8 Hz flicker)

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
                :hearts, :game_over, :moved, :blink_until_tick, :slow_until_tick,
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
    @moved = false
    @blink_until_tick = 0
    @slow_until_tick = 0
    @reached_platform = false
  end

  # Move left/right with the arrow keys (no wrapping — clamp to screen); space
  # jumps when grounded. Frozen while locked, until the player re-authenticates.
  def update(args)
    return if @locked || @game_over

    speed = slowed?(args.state.tick_count) ? SLOW_MOVE_SPEED : MOVE_SPEED
    if args.inputs.keyboard.left
      @x -= speed
      @facing = :west
      @moved = true
    elsif args.inputs.keyboard.right
      @x += speed
      @facing = :east
      @moved = true
    else
      @facing = :south
    end

    @x = @x.clamp(0, args.state.level.world_w - WIDTH)

    # Jump on the press edge so holding space doesn't re-launch every frame.
    if args.inputs.keyboard.key_down.space && @grounded
      @vy = JUMP_SPEED
      @grounded = false
    end

    @vy -= GRAVITY
    prev_y = @y
    @y += @vy

    @grounded = false
    # Re-ground only while crossing the floor line from above (prev_y >= GROUND_Y),
    # like the one-way platform check below — otherwise a player already sunk into a
    # pit would snap back the instant their center cleared the gap horizontally.
    if @y <= GROUND_Y && prev_y >= GROUND_Y && !args.state.level.over_hole?(self)
      @y = GROUND_Y
      @vy = 0
      @grounded = true
    elsif @vy <= 0 && (top = args.state.level.platform_landing_top(self, prev_y))
      # Settle onto the one-way platform the level says we crossed this frame.
      @y = top
      @vy = 0
      @grounded = true
      @reached_platform = true
    end
  end

  # A Mario-style stomp: the player is descending (@vy < 0) and their feet are
  # above the enemy's vertical midpoint — i.e. they came down onto its head, not
  # into its side. A side/ground hit (@vy >= 0, or feet low on the body) is not a
  # stomp and still triggers the re-auth flow.
  def stomping?(enemy)
    @vy < 0 && @y > enemy.y + enemy.h / 2
  end

  # Hop up off a stomped enemy and leave the ground.
  def bounce
    @vy = STOMP_BOUNCE
    @grounded = false
  end

  def hurt(args)
    @blink_until_tick = args.state.tick_count + BLINK_TICKS
  end

  # A side/ground hit from an auth enemy: dock a heart, then (unless that was the
  # last one) freeze for the re-auth and start the damage blink. On a fatal hit the
  # player just drops to zero hearts — Main watches for that and ends the run.
  def take_hit(args, auth)
    @hearts -= 1
    return if @hearts <= 0
    @locked = true
    @pending_challenge = auth
    hurt(args)
  end

  # A buffering enemy lagged the player: crawl their move speed for SLOW_TICKS frames.
  def slow(args)
    @slow_until_tick = args.state.tick_count + SLOW_TICKS
  end

  def slowed?(tick)
    tick < @slow_until_tick
  end

  def invincible?(args)
    args.state.tick_count < @blink_until_tick
  end

  # Draw the figure as stacked brutalist primitives within the 64x96 hitbox: two
  # INK legs, an INK-bordered INDIGO torso (platform card treatment), a tan neck,
  # then a tan head with a dark hair band and two eyes that slide toward @facing as
  # the directional cue (centered when idle/:south). World x is shifted by the
  # camera offset to screen space.
  def render(args, camera_x = 0)
    sx = @x - camera_x

    # Damage flicker: skip the whole figure on the "off" half of the blink.
    return if invincible?(args) &&
              args.state.tick_count % (BLINK_INTERVAL * 2) >= BLINK_INTERVAL

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
  end

  # A brutalist card like the platforms (entities/platform.rb): an INK rect with a
  # fill inset by BORDER (INDIGO by default; the head passes SKIN). Coords are
  # already screen-space.
  def card(args, x, y, w, h, fill = INDIGO)
    args.outputs.solids << { x: x, y: y, w: w, h: h, r: INK[0], g: INK[1], b: INK[2] }
    args.outputs.solids << { x: x + BORDER, y: y + BORDER, w: w - 2 * BORDER, h: h - 2 * BORDER,
                             r: fill[0], g: fill[1], b: fill[2] }
  end

  def serialize
    { x: @x, y: @y, w: @w, h: @h, vy: @vy, grounded: @grounded, facing: @facing,
      locked: @locked, colliding: @colliding, lock_confirmed: @lock_confirmed,
      pending_challenge: @pending_challenge, hearts: @hearts, game_over: @game_over,
      moved: @moved, blink_until_tick: @blink_until_tick, slow_until_tick: @slow_until_tick,
      reached_platform: @reached_platform }
  end

  def inspect = serialize.to_s
  def to_s = serialize.to_s
end
