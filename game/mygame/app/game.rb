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
    @collision_report = Network::OneShot.new
    @death_report = Network::OneShot.new
    @unlock_poller = nil
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
            !@player.lock_confirmed && !@collision_report.pending?
        @collision_report.post(Network.challenge_start_url(@args, @player.pending_challenge))
      end
    end

    if @level.complete?
      @level.next_level ? advance_level : beat_game
    end

    end_run if out_of_time?

    @collision_report.update { @player.confirm_lock! }
    @death_report.update

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
    Ui::Hearts.new(@args, @player.hearts).draw
    @level.draw_hud(@args)
    draw_overlay
  end

  def draw_overlay
    case phase
    when :beaten then Ui::CourseComplete.new(@args).draw
    when :ended then Ui::VideoEnded.new(@args).draw
    when :buffering then Ui::BufferingOverlay.new(@args, @player.pending_challenge).draw
    when :paused then Ui::PausedOverlay.new(@args).draw
    when :intro then Ui::LevelIntro.new(@args, @level).draw
    when :dialogue then Dialogue.new(@args, @level.current_dialogue(@args), @level.accent).draw
    else
      draw_lag_indicator if @player.slowed?(tick_count)
      @level.draw(@args)
    end
  end

  def phase
    return :loading unless @booted
    return :beaten if @beaten
    return :ended if @player.game_over
    return :buffering if @player.locked
    return :paused if @paused
    return :intro if intro_active?
    return :dialogue if dialogue_active?
    :playing
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

  def end_run
    return if @player.game_over
    @player.die!
    @death_report.post(Network.death_url(@args))
  end

  def poll_unlock
    @unlock_poller ||= Network::Poller.new(Network.challenge_status_url(@args, @player.pending_challenge))
    @unlock_poller.poll(tick_count) { |data| unlock_player if data["locked"] == false }
  end

  def unlock_player
    @unlock_poller = nil
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
    @unlock_poller = nil
    setup_level
    begin_level_intro
    Network::Levels.playing(@args, @level.number)
  end
end
