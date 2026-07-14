class Game
  attr_reader :player, :level, :camera_x, :camera_y, :heart_drop_chance, :rewind_drop_chance

  def initialize(level_builder, extra_levels: {}, heart_drop_chance: nil, rewind_drop_chance: nil)
    @level_builder = level_builder
    @extra_levels = extra_levels
    @heart_drop_chance = heart_drop_chance || Level::HEART_DROP_CHANCE
    @rewind_drop_chance = rewind_drop_chance || Level::REWIND_DROP_CHANCE
    @player = Player.new
    @collision_manager = CollisionManager.new
    @level = build_level
    @camera_x = 0
    @camera_y = 0
    @started = false
    @paused = false
    @beaten = false
    @captions_on = true
    @time_hint_at = nil
    @time_hint_threshold = nil
    @collision_report = Network::OneShot.new
    @death_report = Network::OneShot.new
    @unlock_poller = nil
  end

  def tick(frame)
    @frame = frame

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

  def extra_level(number)
    data = @extra_levels[number]
    JsonLevel.new(self, data, number) if data
  end

  def time_hint_active? = !@time_hint_at.nil? && time_hint_elapsed < TIME_HINT_TICKS

  def time_hint_elapsed = tick_count - @time_hint_at

  private

  def tick_count = @frame.tick_count

  def build_level
    @level_builder.call(self)
  end

  def handle_caption_input
    hit = @frame.inputs.mouse.click && @frame.inputs.mouse.point.inside_rect?(CC_BUTTON)
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

    toggle = @frame.inputs.keyboard.key_down.escape ||
             (@frame.inputs.mouse.click && @frame.inputs.mouse.point.inside_rect?(PLAY_BUTTON))
    @paused = !@paused if toggle
    !!toggle
  end

  def handle_dialogue_input
    return unless dialogue_active?

    @level.advance_dialogue if advance_pressed?
  end

  def advance_pressed?
    @frame.inputs.keyboard.key_down.space || @frame.inputs.keyboard.key_down.e
  end

  def update_world
    @player.update(@frame, @level)

    handle_hole_fall unless @player.game_over

    @camera_x =
      (@player.x + @player.w / 2 - SCREEN_W / 2)
        .clamp(0, @level.world_w - SCREEN_W)

    @camera_y =
      (@player.y + @player.h / 2 - SCREEN_H * 3 / 4)
        .clamp(0, WORLD_H - SCREEN_H)

    @level.update(@frame)

    @level.enemies.each { |enemy| enemy.update if enemy.alive } unless @player.game_over

    unless @player.game_over
      cm = @collision_manager
      cm.reset
      @level.platforms.each { |plat| cm.add(plat) }
      @level.enemies.each { |enemy| cm.add(enemy) if enemy.alive }
      @level.collectables.each { |pickup| cm.add(pickup) if pickup.alive? }
      cm.add(@player)
      cm.resolve(@frame)

      if @player.dead?
        end_run
      elsif @player.locked && @player.pending_challenge &&
            !@player.lock_confirmed && !@collision_report.pending?
        @collision_report.post(Network.challenge_start_url(@player.pending_challenge))
      end
    end

    if @level.complete?
      @level.next_level ? advance_level : beat_game
    end

    end_run if out_of_time?
    update_time_hint

    @collision_report.update { @player.confirm_lock! }
    @death_report.update

    poll_unlock if @player.locked && @player.lock_confirmed

    restart_run if @player.game_over && @frame.inputs.keyboard.key_down.r
  end

  def handle_hole_fall
    return if @player.y > HOLE_FALL_LIMIT

    @player.fall_into_hole(@frame, @level)
    end_run if @player.dead?
  end

  def render_world
    Ui::Background.new(@frame).draw

    hidden_for_dialogue = dialogue_active? && @level.dialogue_hides_scene?
    unless intro_active? || hidden_for_dialogue
      @level.platforms.each { |plat| plat.render(@frame, @camera_x, @camera_y) }

      @level.enemies.each { |enemy| enemy.render(@frame, @camera_x, @camera_y) if enemy.alive }

      @level.collectables.each { |pickup| pickup.render(@frame, @camera_x, @camera_y) if pickup.alive? }

      @level.render_world(@frame, @camera_x, @camera_y)

      @player.render(@frame, @camera_x, @camera_y)

      draw_rewind_flashes
    end

    Ui::ControlBar.new(@frame, self).draw
    Ui::Hearts.new(@frame, @player.hearts).draw
    @level.draw_hud(@frame)
    draw_overlay
  end

  def draw_overlay
    case phase
    when :beaten then Ui::CourseComplete.new(@frame).draw
    when :ended then Ui::VideoEnded.new(@frame).draw
    when :buffering then Ui::BufferingOverlay.new(@frame, @player.pending_challenge).draw
    when :paused then Ui::PausedOverlay.new(@frame).draw
    when :intro then Ui::LevelIntro.new(@frame, @level).draw
    when :dialogue then Dialogue.new(@frame, @level.current_dialogue(@frame), @level.accent).draw
    else
      draw_lag_indicator if @player.slowed?(tick_count)
      Ui::TimeHint.new(@frame, self).draw if time_hint_active?
      @level.draw(@frame)
    end
  end

  def phase
    return :beaten if @beaten
    return :ended if @player.game_over
    return :buffering if @player.locked
    return :paused if @paused
    return :intro if intro_active?
    return :dialogue if dialogue_active?
    :playing
  end

  def draw_lag_indicator
    @frame.outputs.labels << { x: @player.x - @camera_x + @player.w / 2,
                               y: @player.y + @player.h + 26 - @camera_y, text: "buffering...",
                               size_enum: -1, alignment_enum: 1, font: FONT_MONO,
                               r: MUTED[0], g: MUTED[1], b: MUTED[2] }
  end

  def out_of_time?
    !@player.game_over && progress >= 1.0
  end

  def update_time_hint
    return if @player.game_over

    threshold = crossed_time_threshold
    return if threshold == @time_hint_threshold

    dropped_lower = threshold && (@time_hint_threshold.nil? || threshold < @time_hint_threshold)
    @time_hint_threshold = threshold
    @time_hint_at = tick_count if dropped_lower
  end

  def crossed_time_threshold
    remaining = @level.remaining_seconds(tick_count)
    TIME_HINT_THRESHOLDS.select { |threshold| remaining <= threshold }.min
  end

  def draw_rewind_flashes
    @level.expire_rewind_flashes(tick_count)
    @level.rewind_flashes.each { |flash| flash.render(@frame, @camera_x, @camera_y) }
  end

  def end_run
    return if @player.game_over
    @player.die!
    @death_report.post(Network.death_url)
  end

  def poll_unlock
    @unlock_poller ||= Network::Poller.new(Network.challenge_status_url(@player.pending_challenge))
    @unlock_poller.poll(tick_count) { |data| unlock_player if data["locked"] == false }
  end

  def unlock_player
    @unlock_poller = nil
    @player.unlock!
    @level.on_unlock(@frame)
  end

  def setup_level
    @player.place_at(@level.start_x, @level.start_y)
    @camera_x = 0
    @camera_y = 0
    @level.setup(@frame)
  end

  def beat_game
    return if @beaten
    @beaten = true
    Network::Levels.complete(@level.number)
  end

  def advance_level
    Network::Levels.complete(@level.number)
    @level = @level.next_level
    setup_level
    begin_level_intro
    Network::Levels.playing(@level.number)
  end

  def begin_level_intro
    @level.begin_clock(tick_count)
  end

  def dialogue_active?
    @started && !intro_active? &&
      !@player.game_over && !@level.current_dialogue(@frame).nil?
  end

  def restart_run
    @player = Player.new
    @level = build_level
    @unlock_poller = nil
    @time_hint_at = nil
    @time_hint_threshold = nil
    setup_level
    begin_level_intro
    Network::Levels.playing(@level.number)
  end
end
