require "app/requires.rb"

module Main
  def tick(args)
    Network.base_url(args)
    args.state.player ||= Player.new
    args.state.collision_manager ||= CollisionManager.new
    args.state.level ||= Level.build(args.state.start_level || 0)
    args.state.captions_on = true if args.state.captions_on.nil?

    return LoadingScene.new(args).tick unless args.state.start_request == :done

    cc_clicked = Handlers.caption_input(args)
    start_run(args) unless args.state.started
    if args.state.started
      toggled = handle_pause_input(args)
      handle_dialogue_input(args)
      update_world(args) unless args.state.paused || toggled || cc_clicked ||
                                State.intro_active?(args) || dialogue_active?(args) ||
                                args.state.beaten
    end

    render_world(args)
  end

  def start_run(args)
    args.state.started = true
    setup_level(args)
    begin_level_intro(args)
  end

  def handle_pause_input(args)
    return false if args.state.player.game_over || args.state.player.locked || dialogue_active?(args)

    toggle = args.inputs.keyboard.key_down.escape ||
             (args.inputs.mouse.click && args.inputs.mouse.point.inside_rect?(PLAY_BUTTON))
    args.state.paused = !args.state.paused if toggle
    !!toggle
  end

  def handle_dialogue_input(args)
    return unless dialogue_active?(args)

    args.state.level.advance_dialogue if advance_pressed?(args)
  end

  def advance_pressed?(args)
    args.inputs.keyboard.key_down.space || args.inputs.keyboard.key_down.e
  end

  def update_world(args)
    args.state.player.update(args)

    handle_hole_fall(args) unless args.state.player.game_over

    args.state.camera_x =
      (args.state.player.x + args.state.player.w / 2 - SCREEN_W / 2)
        .clamp(0, args.state.level.world_w - SCREEN_W)

    args.state.level.update(args)

    args.state.level.enemies.each { |enemy| enemy.update if enemy.alive } unless args.state.player.game_over

    unless args.state.player.game_over
      cm = args.state.collision_manager
      cm.reset
      args.state.level.platforms.each { |plat| cm.add(plat) }
      args.state.level.enemies.each { |enemy| cm.add(enemy) if enemy.alive }
      args.state.level.collectables.each { |pickup| cm.add(pickup) if pickup.alive? }
      cm.add(args.state.player)
      cm.resolve(args)

      player = args.state.player
      if player.hearts <= 0
        end_run(args)
      elsif player.locked && player.pending_challenge &&
            !player.lock_confirmed && args.state.collision_request.nil?
        report_collision(args, player.pending_challenge)
      end
    end

    if args.state.level.complete?
      args.state.level.next_level ? advance_level(args) : beat_game(args)
    end

    end_run(args) if out_of_time?(args)

    # Drop the non-serializable request handle so DragonRuby's state export works.
    if args.state.collision_request &&
       args.state.collision_request[:complete]
      args.state.collision_request = nil
      args.state.player.lock_confirmed = true
    end

    Network::Death.maybe_complete(args.state)

    poll_unlock(args) if args.state.player.locked && args.state.player.lock_confirmed

    restart_run(args) if args.state.player.game_over && args.inputs.keyboard.key_down.r
  end

  def handle_hole_fall(args)
    player = args.state.player
    return if player.y > HOLE_FALL_LIMIT

    player.hearts -= 1
    if player.hearts <= 0
      end_run(args)
    else
      cx = player.x + player.w / 2
      hole = args.state.level.holes.select { |h| h.x <= cx }.max_by(&:x)
      back = (hole ? hole.x : player.x) - HOLE_RESPAWN_BACK
      player.x = back.clamp(0, args.state.level.world_w - Player::WIDTH)
      player.y = GROUND_Y
      player.vy = 0
      player.grounded = true
      player.hurt(args)
    end
  end

  def render_world(args)
    cam = args.state.camera_x ||= 0

    Ui::Background.new(args).draw

    hidden_for_dialogue = dialogue_active?(args) && args.state.level.dialogue_hides_scene?
    unless State.intro_active?(args) || hidden_for_dialogue
      args.state.level.platforms.each { |plat| plat.render(args, cam) }

      args.state.level.enemies.each { |enemy| enemy.render(args, cam) if enemy.alive }

      args.state.level.collectables.each { |pickup| pickup.render(args, cam) if pickup.alive? }

      args.state.level.render_world(args, cam)

      args.state.player.render(args, cam)
    end

    Ui::ControlBar.new(args).draw
    draw_hearts(args)
    args.state.level.draw_hud(args)

    if args.state.beaten
      Ui::CourseComplete.new(args).draw
    elsif args.state.player.game_over
      draw_video_ended(args)
    elsif args.state.player.locked
      draw_buffering(args)
    elsif args.state.paused
      draw_paused(args)
    elsif State.intro_active?(args)
      draw_level_intro(args)
    elsif dialogue_active?(args)
      Dialogue.new(args, args.state.level.current_dialogue(args), args.state.level.accent).draw
    else
      draw_lag_indicator(args) if args.state.player.slowed?(args.state.tick_count)
      args.state.level.draw(args)
    end
  end

  def draw_lag_indicator(args)
    player = args.state.player
    args.outputs.labels << { x: player.x - args.state.camera_x + player.w / 2,
                             y: player.y + player.h + 26, text: "buffering...",
                             size_enum: -1, alignment_enum: 1, font: FONT_MONO,
                             r: MUTED[0], g: MUTED[1], b: MUTED[2] }
  end

  def out_of_time?(args)
    !args.state.player.game_over && State.progress(args) >= 1.0
  end

  def draw_hearts(args)
    Player::MAX_HEARTS.times do |i|
      have = i < args.state.player.hearts
      args.outputs.sprites << { x: 24 + i * 42,
                                y: SCREEN_H - 60,
                                w: 36,
                                h: 33,
                                path: have ? "sprites/ui/heart_hardmode.png" : "sprites/ui/heart_empty.png" }
    end
  end

  def draw_level_intro(args)
    level = args.state.level
    elapsed = args.state.level.intro_elapsed(args.state.tick_count)
    alpha = if elapsed < LEVEL_INTRO_FADE_IN
              255 * elapsed / LEVEL_INTRO_FADE_IN
    elsif elapsed > LEVEL_INTRO_TICKS - LEVEL_INTRO_FADE_OUT
              255 * (LEVEL_INTRO_TICKS - elapsed) / LEVEL_INTRO_FADE_OUT
    else
              255
    end
    alpha = alpha.clamp(0, 255)

    cx = 640
    cy = 392
    h = 152
    accent = level.accent

    # 0.6 px per point of font size estimates the title width; there's no way to
    # measure a string without the engine.
    title = level.title
    title_size = 40
    pad_x = 48
    est_w = title.length * title_size * 0.6
    w = (est_w + 2 * pad_x).clamp(520, SCREEN_W - 120).to_i
    title_size = ((w - 2 * pad_x) * title_size / est_w).to_i if est_w > w - 2 * pad_x
    left = cx - w / 2
    bottom = cy - h / 2

    args.outputs.solids << { x: left + 8, y: bottom - 8, w: w, h: h,
                             r: INK[0], g: INK[1], b: INK[2], a: alpha }
    args.outputs.solids << { x: left, y: bottom, w: w, h: h,
                             r: INK[0], g: INK[1], b: INK[2], a: alpha }
    args.outputs.solids << { x: left + 4, y: bottom + 4, w: w - 8, h: h - 8,
                             r: CARD[0], g: CARD[1], b: CARD[2], a: alpha }

    args.outputs.labels << { x: cx, y: cy + 44, text: level.chapter_label.upcase,
                             size_px: 18, font: FONT_MONO_B,
                             r: accent[0], g: accent[1], b: accent[2], a: alpha,
                             anchor_x: 0.5, anchor_y: 0.5 }
    args.outputs.solids << { x: cx - 28, y: cy + 26, w: 56, h: 4,
                             r: accent[0], g: accent[1], b: accent[2], a: alpha }
    args.outputs.labels << { x: cx, y: cy - 18, text: title,
                             size_px: title_size, font: FONT_DISPLAY,
                             r: INK[0], g: INK[1], b: INK[2], a: alpha,
                             anchor_x: 0.5, anchor_y: 0.5 }
  end

  def draw_paused(args)
    args.outputs.solids << { x: 0, y: BAR_TOP, w: SCREEN_W, h: SCREEN_H - BAR_TOP,
                             r: PAPER[0], g: PAPER[1], b: PAPER[2], a: 90 }
    cx = 640
    cy = 440
    args.outputs.solids << { x: cx - 16, y: cy + 26, x2: cx - 16, y2: cy - 26,
                             x3: cx + 30, y3: cy,
                             r: INK[0], g: INK[1], b: INK[2] }
    args.outputs.labels << { x: cx, y: cy - 64, text: "PAUSED",
                             size_px: 24, font: FONT_MONO_B,
                             r: INK[0], g: INK[1], b: INK[2],
                             anchor_x: 0.5, anchor_y: 0.5 }
    args.outputs.labels << { x: cx, y: cy - 96, text: "press play or escape to resume",
                             size_px: 16, font: FONT_MONO,
                             r: MUTED[0], g: MUTED[1], b: MUTED[2],
                             anchor_x: 0.5, anchor_y: 0.5 }

    controls = [ "A / D  or  ← →    move",
                 "Space    jump" ]
    controls.each_with_index do |line, i|
      args.outputs.labels << { x: cx, y: cy - 148 - i * 30, text: line,
                               size_px: 16, font: FONT_MONO,
                               r: MUTED[0], g: MUTED[1], b: MUTED[2],
                               anchor_x: 0.5, anchor_y: 0.5 }
    end
  end

  def draw_buffering(args)
    color = challenge_color(args.state.player.pending_challenge)

    Ui::Spinner.new(args).draw(640, 470, color)

    label = case args.state.player.pending_challenge
    when :passkey then "BUFFERING — approve the passkey toast to resume →"
    when :password then "BUFFERING — enter your password in the toast to resume →"
    else "BUFFERING — enter your TOTP code in the toast to resume →"
    end
    args.outputs.labels << { x: 640, y: 420, text: label,
                             size_px: 22, font: FONT_MONO_B,
                             r: color[0], g: color[1], b: color[2],
                             anchor_x: 0.5, anchor_y: 0.5 }
  end

  def draw_video_ended(args)
    args.outputs.solids << { x: 0, y: 0, w: SCREEN_W, h: SCREEN_H,
                             r: INDIGO[0], g: INDIGO[1], b: INDIGO[2], a: 184 }
    args.outputs.labels << { x: 640, y: 408, text: "Video Ended",
                             size_px: 96, font: FONT_DISPLAY,
                             r: PAPER[0], g: PAPER[1], b: PAPER[2],
                             anchor_x: 0.5, anchor_y: 0.5 }
    args.outputs.solids << { x: 640 - 210, y: 350, w: 420, h: 5,
                             r: RED[0], g: RED[1], b: RED[2] }
    args.outputs.labels << { x: 640, y: 318, text: "↺ Replay · press R",
                             size_px: 22, font: FONT_MONO,
                             r: FAINT_INK[0], g: FAINT_INK[1], b: FAINT_INK[2],
                             anchor_x: 0.5, anchor_y: 0.5 }
  end

  def challenge_color(kind)
    case kind
    when :passkey then BLUE
    when :password then AMBER
    else PURPLE
    end
  end

  def end_run(args)
    return if args.state.player.game_over
    args.state.player.game_over = true
    Network::Death.start(args)
  end

  def report_collision(args, kind)
    args.state.collision_request = DR.http_post(
      start_url(args, kind),
      {},
      [ "Content-Type: application/x-www-form-urlencoded" ]
    )
  end

  def report_level_complete(args, level)
    Network::Levels.complete(args, level)
  end

  def report_now_playing(args, level)
    Network::Levels.playing(args, level)
  end

  def poll_unlock(args)
    request = args.state.status_request

    if !request
      if args.state.tick_count >= (args.state.next_poll_tick || 0)
        args.state.status_request = DR.http_get(status_url(args, args.state.player.pending_challenge))
      end
    elsif request[:complete]
      if request[:http_response_code] == 200
        data = DR.parse_json(request[:response_data])
        unlock_player(args) if data && data["locked"] == false
      end
      args.state.status_request = nil
      args.state.next_poll_tick = args.state.tick_count + 30
    end
  end

  def unlock_player(args)
    args.state.player.locked = false
    args.state.player.lock_confirmed = false
    args.state.player.pending_challenge = nil
    args.state.level.on_unlock(args)
  end

  def setup_level(args)
    args.state.player.x = args.state.level.start_x
    args.state.camera_x = 0
    args.state.level.setup(args)
  end

  def beat_game(args)
    return if args.state.beaten
    args.state.beaten = true
    Network::Levels.complete(args, args.state.level.number)
  end

  def advance_level(args)
    report_level_complete(args, args.state.level.number)
    args.state.level = args.state.level.next_level
    setup_level(args)
    begin_level_intro(args)
    report_now_playing(args, args.state.level.number)
  end

  def begin_level_intro(args)
    args.state.level.begin_clock(args.state.tick_count)
  end

  def dialogue_active?(args)
    args.state.started && !State.intro_active?(args) &&
      !args.state.player.game_over && !args.state.level.current_dialogue(args).nil?
  end

  def restart_run(args)
    args.state.player = Player.new
    args.state.level = Level.build(args.state.start_level || 0)
    setup_level(args)
    begin_level_intro(args)
    report_now_playing(args, args.state.level.number)
  end

  def start_url(args, kind) = "#{Network.base_url(args)}/games/#{kind}/start"
  def status_url(args, kind) = "#{Network.base_url(args)}/games/#{kind}/status"
end
