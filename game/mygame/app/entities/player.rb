class Player
  WIDTH = 64
  HEIGHT = 96
  MOVE_SPEED = 8
  SLOW_MOVE_SPEED = 3
  SLOW_TICKS = 180
  JUMP_SPEED = 20
  STOMP_BOUNCE = 12
  GRAVITY = 1
  MAX_HEARTS = 3
  BLINK_TICKS = 60
  BLINK_INTERVAL = 4

  BORDER     = 3
  LEG_H      = 14
  LEG_W      = 18
  TORSO_H    = 46
  NECK_H     = 4
  NECK_W     = 12
  HEAD_H     = 30
  HEAD_INSET = 14
  HAIR_H     = 8
  EYE        = 4
  EYE_GAP    = 8
  FACE_SHIFT = 5

  SKIN = [ 222, 184, 135 ]
  HAIR = [ 74, 52, 36 ]

  attr_accessor :x, :y, :w, :h, :vy, :grounded
  attr_reader :facing, :locked, :lock_confirmed, :pending_challenge,
              :hearts, :game_over, :moved, :reached_platform

  def initialize
    @x = 200
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
    @prev_y = @y
    @pickup_count = 0
    @stomped_this_tick = false
    @dropping = false
    @drop_floor_y = 0
  end

  def update(args, level)
    @stomped_this_tick = false
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

    @x = @x.clamp(0, level.world_w - WIDTH)

    if args.inputs.keyboard.key_down.space && @grounded
      @vy = JUMP_SPEED
      @grounded = false
    end

    fell_clear_of_ledge = @y < @drop_floor_y
    reversed_upward = @vy > 0
    @dropping = false if @dropping && (fell_clear_of_ledge || reversed_upward)

    drop_pressed = args.inputs.keyboard.key_down.down || args.inputs.keyboard.key_down.s
    if drop_pressed && @grounded && @y > GROUND_Y
      @dropping = true
      @drop_floor_y = @y - Platform::H
      @grounded = false
    end

    @vy -= GRAVITY
    @prev_y = @y
    @y += @vy

    @grounded = false
    if landing_on_floor?(level)
      @y = GROUND_Y
      @vy = 0
      @grounded = true
    end
  end

  def stomping?(enemy)
    (@vy < 0 || @stomped_this_tick) && @y > enemy.y + enemy.h / 2
  end

  def bounce
    @vy = STOMP_BOUNCE
    @grounded = false
    @stomped_this_tick = true
  end

  def hurt(args)
    @blink_until_tick = args.state.tick_count + BLINK_TICKS
  end

  def heal
    @hearts = [ @hearts + 1, MAX_HEARTS ].min
  end

  def dead? = @hearts <= 0

  def die!
    @game_over = true
  end

  def lock!(challenge)
    @locked = true
    @pending_challenge = challenge
  end

  def confirm_lock!
    @lock_confirmed = true
  end

  def unlock!
    @locked = false
    @lock_confirmed = false
    @pending_challenge = nil
  end

  def fall_into_hole(args, level)
    @hearts -= 1
    return if dead?

    cx = @x + @w / 2
    hole = level.holes.select { |h| h.x <= cx }.max_by(&:x)
    back = (hole ? hole.x : @x) - HOLE_RESPAWN_BACK
    @x = back.clamp(0, level.world_w - WIDTH)
    @y = GROUND_Y
    @vy = 0
    @grounded = true
    hurt(args)
  end

  def record_pickup
    seq = @pickup_count
    @pickup_count += 1
    seq
  end

  def on_collision(other, args)
    case other
    when Enemy then collide_with_enemy(other, args)
    when Platform then land_on(other)
    end
  end

  def slow(args)
    @slow_until_tick = args.state.tick_count + SLOW_TICKS
  end

  def slowed?(tick)
    tick < @slow_until_tick
  end

  def invincible?(args)
    args.state.tick_count < @blink_until_tick
  end

  def render(args, camera_x = 0)
    sx = @x - camera_x

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

    args.outputs.solids << { x: head_x + BORDER, y: head_y + HEAD_H - BORDER - HAIR_H,
                             w: head_w - 2 * BORDER, h: HAIR_H, r: HAIR[0], g: HAIR[1], b: HAIR[2] }

    shift = @facing == :west ? -FACE_SHIFT : (@facing == :east ? FACE_SHIFT : 0)
    eye_cx = sx + @w / 2
    [ eye_cx - EYE_GAP / 2 - EYE, eye_cx + EYE_GAP / 2 ].each do |ex|
      args.outputs.solids << { x: ex + shift, y: head_y + 10, w: EYE, h: EYE,
                               r: INK[0], g: INK[1], b: INK[2] }
    end
  end

  def card(args, x, y, w, h, fill = INDIGO)
    args.outputs.solids << { x: x, y: y, w: w, h: h, r: INK[0], g: INK[1], b: INK[2] }
    args.outputs.solids << { x: x + BORDER, y: y + BORDER, w: w - 2 * BORDER, h: h - 2 * BORDER,
                             r: fill[0], g: fill[1], b: fill[2] }
  end

  private

  def landing_on_floor?(level)
    @y <= GROUND_Y && @prev_y >= GROUND_Y && !level.over_hole?(self)
  end

  def collide_with_enemy(enemy, args)
    if enemy.stompable? && stomping?(enemy)
      bounce
    elsif enemy.slows?
      slow(args)
    elsif !invincible?(args)
      take_hit(args, enemy.auth)
    end
  end

  def land_on(platform)
    return if @dropping
    top = platform.y + platform.h
    return unless @vy <= 0 && @prev_y >= top && @y <= top

    @y = top
    @vy = 0
    @grounded = true
    @reached_platform = true
  end

  def take_hit(args, auth)
    @hearts -= 1
    return if dead?
    lock!(auth)
    hurt(args)
  end
end
