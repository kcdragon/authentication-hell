class Game
  attr_reader :player, :level, :camera_x

  def initialize
    @player = Player.new
    @collision_manager = CollisionManager.new
    @level = Level.build(0, self)
    @camera_x = 0
    @started = false
    @paused = false
    @beaten = false
    @booted = false
    @captions_on = true
    @start_level = nil
  end

  def tick(args)
    @args = args
    Network.base_url(args)

    return boot_tick unless @booted

    cc_clicked = handle_caption_input
    start_run unless @started
    toggled = handle_pause_input
    handle_dialogue_input
    update_world unless @paused || toggled || cc_clicked ||
                        intro_active? || dialogue_active? || @beaten

    render_world
  end

  def started? = @started

  def paused? = @paused

  def beaten? = @beaten

  def captions_on? = @captions_on

  def progress = @level.progress(tick_count)

  def intro_active? = @started && @level.intro_active?(tick_count)

  private

  def tick_count = @args.state.tick_count

  def boot_tick
    poll_start_request
    handle_caption_input
    LoadingScene.new(@args, self).draw
  end

  def poll_start_request
    @start_request ||= DR.http_get(Network::Start.url(@args))
    return unless @start_request[:complete]

    if @start_request[:http_response_code] == 200
      data = DR.parse_json(@start_request[:response_data])
      @start_level = data["start_level"] if data && data["start_level"]
    end
    @level = Level.build(@start_level || 0, self)
    @start_request = nil
    @booted = true
  end

  def handle_caption_input
    hit = @args.inputs.mouse.click && @args.inputs.mouse.point.inside_rect?(CC_BUTTON)
    @captions_on = !@captions_on if hit
    !!hit
  end

  def start_run
    @started = true
    setup_level
    begin_level_intro
  end

  def handle_pause_input
    return false if @player.game_over || @player.locked || dialogue_active?

    toggle = @args.inputs.keyboard.key_down.escape ||
             (@args.inputs.mouse.click && @args.inputs.mouse.point.inside_rect?(PLAY_BUTTON))
    @paused = !@paused if toggle
    !!toggle
  end

  def handle_dialogue_input
    return unless dialogue_active?

    @level.advance_dialogue if advance_pressed?
  end

  def advance_pressed?
    @args.inputs.keyboard.key_down.space || @args.inputs.keyboard.key_down.e
  end

  def update_world
    @player.update(@args, @level)

    handle_hole_fall unless @player.game_over

    @camera_x =
      (@player.x + @player.w / 2 - SCREEN_W / 2)
        .clamp(0, @level.world_w - SCREEN_W)

    @level.update(@args)

    @level.enemies.each { |enemy| enemy.update if enemy.alive } unless @player.game_over

    unless @player.game_over
      cm = @collision_manager
      cm.reset
      @level.platforms.each { |plat| cm.add(plat) }
      @level.enemies.each { |enemy| cm.add(enemy) if enemy.alive }
      @level.collectables.each { |pickup| cm.add(pickup) if pickup.alive? }
      cm.add(@player)
      cm.resolve(@args)

      if @player.dead?
        end_run
      elsif @player.locked && @player.pending_challenge &&
            !@player.lock_confirmed && @collision_request.nil?
        report_collision(@player.pending_challenge)
      end
    end

    if @level.complete?
      @level.next_level ? advance_level : beat_game
    end

    end_run if out_of_time?

    if @collision_request && @collision_request[:complete]
      @collision_request = nil
      @player.confirm_lock!
    end

    @death_request = nil if @death_request && @death_request[:complete]

    poll_unlock if @player.locked && @player.lock_confirmed

    restart_run if @player.game_over && @args.inputs.keyboard.key_down.r
  end

  def handle_hole_fall
    return if @player.y > HOLE_FALL_LIMIT

    @player.fall_into_hole(@args, @level)
    end_run if @player.dead?
  end

  def render_world
    Ui::Background.new(@args).draw

    hidden_for_dialogue = dialogue_active? && @level.dialogue_hides_scene?
    unless intro_active? || hidden_for_dialogue
      @level.platforms.each { |plat| plat.render(@args, @camera_x) }

      @level.enemies.each { |enemy| enemy.render(@args, @camera_x) if enemy.alive }

      @level.collectables.each { |pickup| pickup.render(@args, @camera_x) if pickup.alive? }

      @level.render_world(@args, @camera_x)

      @player.render(@args, @camera_x)
    end

    Ui::ControlBar.new(@args, self).draw
    draw_hearts
    @level.draw_hud(@args)

    if @beaten
      Ui::CourseComplete.new(@args).draw
    elsif @player.game_over
      draw_video_ended
    elsif @player.locked
      draw_buffering
    elsif @paused
      draw_paused
    elsif intro_active?
      draw_level_intro
    elsif dialogue_active?
      Dialogue.new(@args, @level.current_dialogue(@args), @level.accent).draw
    else
      draw_lag_indicator if @player.slowed?(tick_count)
      @level.draw(@args)
    end
  end

  def draw_lag_indicator
    @args.outputs.labels << { x: @player.x - @camera_x + @player.w / 2,
                              y: @player.y + @player.h + 26, text: "buffering...",
                              size_enum: -1, alignment_enum: 1, font: FONT_MONO,
                              r: MUTED[0], g: MUTED[1], b: MUTED[2] }
  end

  def out_of_time?
    !@player.game_over && progress >= 1.0
  end

  def draw_hearts
    Player::MAX_HEARTS.times do |i|
      have = i < @player.hearts
      @args.outputs.sprites << { x: 24 + i * 42,
                                 y: SCREEN_H - 60,
                                 w: 36,
                                 h: 33,
                                 path: have ? "sprites/ui/heart_hardmode.png" : "sprites/ui/heart_empty.png" }
    end
  end

  def draw_level_intro
    elapsed = @level.intro_elapsed(tick_count)
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
    accent = @level.accent

    # 0.6 px per point of font size estimates the title width; there's no way to
    # measure a string without the engine.
    title = @level.title
    title_size = 40
    pad_x = 48
    est_w = title.length * title_size * 0.6
    w = (est_w + 2 * pad_x).clamp(520, SCREEN_W - 120).to_i
    title_size = ((w - 2 * pad_x) * title_size / est_w).to_i if est_w > w - 2 * pad_x
    left = cx - w / 2
    bottom = cy - h / 2

    @args.outputs.solids << { x: left + 8, y: bottom - 8, w: w, h: h,
                              r: INK[0], g: INK[1], b: INK[2], a: alpha }
    @args.outputs.solids << { x: left, y: bottom, w: w, h: h,
                              r: INK[0], g: INK[1], b: INK[2], a: alpha }
    @args.outputs.solids << { x: left + 4, y: bottom + 4, w: w - 8, h: h - 8,
                              r: CARD[0], g: CARD[1], b: CARD[2], a: alpha }

    @args.outputs.labels << { x: cx, y: cy + 44, text: @level.chapter_label.upcase,
                              size_px: 18, font: FONT_MONO_B,
                              r: accent[0], g: accent[1], b: accent[2], a: alpha,
                              anchor_x: 0.5, anchor_y: 0.5 }
    @args.outputs.solids << { x: cx - 28, y: cy + 26, w: 56, h: 4,
                              r: accent[0], g: accent[1], b: accent[2], a: alpha }
    @args.outputs.labels << { x: cx, y: cy - 18, text: title,
                              size_px: title_size, font: FONT_DISPLAY,
                              r: INK[0], g: INK[1], b: INK[2], a: alpha,
                              anchor_x: 0.5, anchor_y: 0.5 }
  end

  def draw_paused
    @args.outputs.solids << { x: 0, y: BAR_TOP, w: SCREEN_W, h: SCREEN_H - BAR_TOP,
                              r: PAPER[0], g: PAPER[1], b: PAPER[2], a: 90 }
    cx = 640
    cy = 440
    @args.outputs.solids << { x: cx - 16, y: cy + 26, x2: cx - 16, y2: cy - 26,
                              x3: cx + 30, y3: cy,
                              r: INK[0], g: INK[1], b: INK[2] }
    @args.outputs.labels << { x: cx, y: cy - 64, text: "PAUSED",
                              size_px: 24, font: FONT_MONO_B,
                              r: INK[0], g: INK[1], b: INK[2],
                              anchor_x: 0.5, anchor_y: 0.5 }
    @args.outputs.labels << { x: cx, y: cy - 96, text: "press play or escape to resume",
                              size_px: 16, font: FONT_MONO,
                              r: MUTED[0], g: MUTED[1], b: MUTED[2],
                              anchor_x: 0.5, anchor_y: 0.5 }

    controls = [ "A / D  or  ← →    move",
                 "Space    jump" ]
    controls.each_with_index do |line, i|
      @args.outputs.labels << { x: cx, y: cy - 148 - i * 30, text: line,
                                size_px: 16, font: FONT_MONO,
                                r: MUTED[0], g: MUTED[1], b: MUTED[2],
                                anchor_x: 0.5, anchor_y: 0.5 }
    end
  end

  def draw_buffering
    color = challenge_color(@player.pending_challenge)

    Ui::Spinner.new(@args).draw(640, 470, color)

    label = case @player.pending_challenge
    when :passkey then "BUFFERING — approve the passkey toast to resume →"
    when :password then "BUFFERING — enter your password in the toast to resume →"
    else "BUFFERING — enter your TOTP code in the toast to resume →"
    end
    @args.outputs.labels << { x: 640, y: 420, text: label,
                              size_px: 22, font: FONT_MONO_B,
                              r: color[0], g: color[1], b: color[2],
                              anchor_x: 0.5, anchor_y: 0.5 }
  end

  def draw_video_ended
    @args.outputs.solids << { x: 0, y: 0, w: SCREEN_W, h: SCREEN_H,
                              r: INDIGO[0], g: INDIGO[1], b: INDIGO[2], a: 184 }
    @args.outputs.labels << { x: 640, y: 408, text: "Video Ended",
                              size_px: 96, font: FONT_DISPLAY,
                              r: PAPER[0], g: PAPER[1], b: PAPER[2],
                              anchor_x: 0.5, anchor_y: 0.5 }
    @args.outputs.solids << { x: 640 - 210, y: 350, w: 420, h: 5,
                              r: RED[0], g: RED[1], b: RED[2] }
    @args.outputs.labels << { x: 640, y: 318, text: "↺ Replay · press R",
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

  def end_run
    return if @player.game_over
    @player.die!
    @death_request = Network::Death.start(@args)
  end

  def report_collision(kind)
    @collision_request = DR.http_post(
      start_url(kind),
      {},
      [ "Content-Type: application/x-www-form-urlencoded" ]
    )
  end

  def poll_unlock
    if !@status_request
      if tick_count >= (@next_poll_tick || 0)
        @status_request = DR.http_get(status_url(@player.pending_challenge))
      end
    elsif @status_request[:complete]
      if @status_request[:http_response_code] == 200
        data = DR.parse_json(@status_request[:response_data])
        unlock_player if data && data["locked"] == false
      end
      @status_request = nil
      @next_poll_tick = tick_count + 30
    end
  end

  def unlock_player
    @player.unlock!
    @level.on_unlock(@args)
  end

  def setup_level
    @player.x = @level.start_x
    @camera_x = 0
    @level.setup(@args)
  end

  def beat_game
    return if @beaten
    @beaten = true
    Network::Levels.complete(@args, @level.number)
  end

  def advance_level
    Network::Levels.complete(@args, @level.number)
    @level = @level.next_level
    setup_level
    begin_level_intro
    Network::Levels.playing(@args, @level.number)
  end

  def begin_level_intro
    @level.begin_clock(tick_count)
  end

  def dialogue_active?
    @started && !intro_active? &&
      !@player.game_over && !@level.current_dialogue(@args).nil?
  end

  def restart_run
    @player = Player.new
    @level = Level.build(@start_level || 0, self)
    setup_level
    begin_level_intro
    Network::Levels.playing(@args, @level.number)
  end

  def start_url(kind) = "#{Network.base_url(@args)}/games/#{kind}/start"
  def status_url(kind) = "#{Network.base_url(@args)}/games/#{kind}/status"
end
