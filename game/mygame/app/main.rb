require "app/requires.rb"

module Main
  def tick(args)
    Network.base_url(args)
    args.state.player ||= Player.new
    args.state.collision_manager ||= CollisionManager.new
    # Seed a level before the loading scene draws the transport (which reads its time
    # limit); /game/start swaps in the real starting level once it resolves.
    args.state.level ||= Level.build(args.state.start_level || 0)
    args.state.captions_on = true if args.state.captions_on.nil?

    # The loading scene owns the frame until /game/start resolves the starting level;
    # the run then begins automatically — the player already pressed ▶ Play on the
    # site, so there's no in-canvas poster — and play takes over.
    return LoadingScene.new(args).tick unless args.state.start_request == :done

    cc_clicked = Handlers.caption_input(args)
    start_run(args) unless args.state.started
    if args.state.started
      toggled = handle_pause_input(args)
      handle_dialogue_input(args)
      # The world stays frozen behind the intro card (and any in-level dialogue) so a
      # level start, and the player's reset to the new scene's left edge, lands while
      # it's covered.
      update_world(args) unless args.state.paused || toggled || cc_clicked ||
                                State.intro_active?(args) || dialogue_active?(args) ||
                                args.state.beaten
    end

    render_world(args)
  end

  # Kick off the run: seed the resolved starting level, play its intro card, then the
  # world unfreezes once the card fades.
  def start_run(args)
    args.state.started = true
    setup_level(args)
    begin_level_intro(args)
  end

  # Pause / resume mid-run via the Escape key or a click on the play/pause button
  # (the only wired transport control). Disallowed while the run is over or buffering
  # a re-auth: there's nothing to pause there, and pausing a lock would stall the
  # unlock poll. Returns whether it toggled this tick so the caller can skip the world
  # update on the frame the player clicks pause.
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

  # One tick of live gameplay (only while the run is started and not over).
  def update_world(args)
    # Input, jumping, gravity, and world-floor/pit landing (frozen while locked), owned
    # by the player; one-way platform landings are entities, resolved below by the
    # CollisionManager.
    args.state.player.update(args)

    # A pit-fall: the player walked off a gap in the ground and dropped through.
    handle_hole_fall(args) unless args.state.player.game_over

    # Horizontal camera: keep the player centered, clamped to the world edges.
    args.state.camera_x =
      (args.state.player.x + args.state.player.w / 2 - SCREEN_W / 2)
        .clamp(0, args.state.level.world_w - SCREEN_W)

    # Per-tick level scripting (e.g. the welcome level spawns its enemy once the player
    # has jumped onto the platform). Reads the camera set just above.
    args.state.level.update(args)

    # Patrol: each enemy paces within its region. Keeps going while the player is
    # locked mid re-auth — only the player freezes — and stops only on game-over.
    args.state.level.enemies.each { |enemy| enemy.update if enemy.alive } unless args.state.player.game_over

    # Register the collidables player-last (so surfaces/enemies settle the player before
    # it's read), resolve contact, then fire the un-testable side effects the collision
    # left on the player: no hearts ends the run, a survivable hit POSTs the re-auth once.
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

    # Goal met: the last level clearing beats the game (freeze on the completion card
    # while the page redirects to the certificate); any other level hands off to the
    # next, which freezes the world behind its intro card. #complete? is false on the
    # new level, so advancing won't re-fire.
    if args.state.level.complete?
      args.state.level.last? ? beat_game(args) : advance_level(args)
    end

    end_run(args) if out_of_time?(args)

    # Only poll once the collision POST has landed, so a status check can't beat
    # the server flag. Drop the (non-serializable) handle so state export works.
    if args.state.collision_request &&
       args.state.collision_request[:complete]
      args.state.collision_request = nil
      args.state.player.lock_confirmed = true
    end

    # Fire-and-forget level report: drop the (non-serializable) handle once it
    # lands so the per-tick state export doesn't choke on it.
    if args.state.level_complete_request && args.state.level_complete_request[:complete]
      args.state.level_complete_request = nil
    end

    Network::Death.maybe_complete(args.state)

    poll_unlock(args) if args.state.player.locked && args.state.player.lock_confirmed

    # On game over the run can be restarted from the "Video Ended" card.
    restart_run(args) if args.state.player.game_over && args.inputs.keyboard.key_down.r
  end

  # Once the player has sunk fully past the floor — only possible over a hole, since
  # jumps go up and the ground/platform checks otherwise pin them to GROUND_Y — dock a
  # heart and, unless that was the last one, drop them back onto solid ground just left
  # of the gap. No re-auth (that's reserved for enemy collisions); the last heart ends
  # the run like any other death.
  def handle_hole_fall(args)
    player = args.state.player
    return if player.y > HOLE_FALL_LIMIT

    player.hearts -= 1
    if player.hearts <= 0
      end_run(args)
    else
      cx = player.x + player.w / 2
      # The nearest gap at or left of the center: they may have drifted past its
      # right edge while falling, so a containment check could miss the pit they
      # actually fell through.
      hole = args.state.level.holes.select { |h| h.x <= cx }.max_by(&:x)
      back = (hole ? hole.x : player.x) - HOLE_RESPAWN_BACK
      player.x = back.clamp(0, args.state.level.world_w - Player::WIDTH)
      player.y = GROUND_Y
      player.vy = 0
      player.grounded = true
      player.hurt(args)
    end
  end

  # Draw the whole frame: the warm-paper playfield, the world entities, then the
  # video-player chrome (control bar / scrubber / HUD) over it, then the active
  # overlay (poster, buffering, or the game-over card).
  def render_world(args)
    # camera_x is set by update_world, which is gated behind `started` — so on the
    # poster frames before play begins it's still unset. Default to 0 so rendering
    # always has a numeric camera.
    cam = args.state.camera_x ||= 0

    Ui::Background.new(args).draw

    # Keep the whole scene (platforms, enemies, collectables, player) hidden behind
    # the intro card, and behind a front-loaded dialogue (the password level) so a
    # level start doesn't pop entities in behind the card. A level whose dialogue
    # surfaces mid-play (the welcome level) leaves the frozen scene visible behind it.
    hidden_for_dialogue = dialogue_active?(args) && args.state.level.dialogue_hides_scene?
    unless State.intro_active?(args) || hidden_for_dialogue
      # World entities are in world coords; each subtracts the camera offset to draw.
      args.state.level.platforms.each { |plat| plat.render(args, cam) }

      args.state.level.enemies.each { |enemy| enemy.render(args, cam) if enemy.alive }

      args.state.level.collectables.each { |pickup| pickup.render(args, cam) if pickup.alive? }

      args.state.level.render_world(args, cam)

      args.state.player.render(args, cam)
    end

    # Video-player chrome over the world: the dark control bar (its lip is the
    # floor line), the scrubber driven by world progress, and the HUD hearts.
    Ui::ControlBar.new(args).draw
    draw_hearts(args)
    args.state.level.draw_hud(args)

    if args.state.beaten
      draw_course_complete(args)
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
      # Each level draws its own prompt as the top closed caption (only here, during
      # live play, where a prompt belongs).
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

  # Three heart slots in the top-left: the full sprite for hearts the player still
  # has, the spent (empty) sprite for the ones they've lost — a crisper read than
  # fading the red one, and it matches the site's locked/empty treatment.
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

  # The level-intro "chapter card": a centered neo-brutalist card (ink shadow → ink
  # border → white face, like the captions) with a CHAPTER N eyebrow over the level
  # title, fading the whole card in then out over LEVEL_INTRO_TICKS while the world
  # holds frozen behind it.
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

    # Fit the card to its title so a long one (the TOTP level) doesn't spill past a
    # fixed box: widen the card to hold the title (clamped to the screen, never below
    # the original 520), and only shrink the display font if even the widest card
    # can't contain it. 0.6 px per point of font size is a safe width estimate for the
    # heavy display face — there's no engine-free way to measure a string here.
    title = level.title
    title_size = 40
    pad_x = 48
    est_w = title.length * title_size * 0.6
    w = (est_w + 2 * pad_x).clamp(520, SCREEN_W - 120).to_i
    title_size = ((w - 2 * pad_x) * title_size / est_w).to_i if est_w > w - 2 * pad_x
    left = cx - w / 2
    bottom = cy - h / 2

    # Hard offset ink shadow, then the ink border, then the white face.
    args.outputs.solids << { x: left + 8, y: bottom - 8, w: w, h: h,
                             r: INK[0], g: INK[1], b: INK[2], a: alpha }
    args.outputs.solids << { x: left, y: bottom, w: w, h: h,
                             r: INK[0], g: INK[1], b: INK[2], a: alpha }
    args.outputs.solids << { x: left + 4, y: bottom + 4, w: w - 8, h: h - 8,
                             r: CARD[0], g: CARD[1], b: CARD[2], a: alpha }

    args.outputs.labels << { x: cx, y: cy + 44, text: "CHAPTER #{level.number + 1}",
                             size_px: 18, font: FONT_MONO_B,
                             r: accent[0], g: accent[1], b: accent[2], a: alpha,
                             anchor_x: 0.5, anchor_y: 0.5 }
    # Short accent rule between the eyebrow and the title.
    args.outputs.solids << { x: cx - 28, y: cy + 26, w: 56, h: 4,
                             r: accent[0], g: accent[1], b: accent[2], a: alpha }
    args.outputs.labels << { x: cx, y: cy - 18, text: title,
                             size_px: title_size, font: FONT_DISPLAY,
                             r: INK[0], g: INK[1], b: INK[2], a: alpha,
                             anchor_x: 0.5, anchor_y: 0.5 }
  end

  # Paused mid-run: a quiet paper scrim over the play area + a centered play glyph,
  # the video "stopped." Resume with Escape or the play button. The pause screen is
  # also where the keyboard controls live (no always-on hint during play).
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

  # Collision → "the tape buffers." The loud brutalist challenge card lives in HTML
  # over the canvas, so the in-canvas treatment stays quiet: a spinner and a single
  # mono line tinted to the enemy's color, pointing at the toast.
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

  # Out of lives → "Video Ended": the one moment the canvas goes loud on its own.
  # A full-canvas indigo dim, the Archivo Black headline in paper, a red rule, and
  # a Replay prompt. No card — the site's flash/challenge surfaces use cards; this
  # dim just speaks the red/error voice without copying a dialog.
  def draw_video_ended(args)
    args.outputs.solids << { x: 0, y: 0, w: SCREEN_W, h: SCREEN_H,
                             r: INDIGO[0], g: INDIGO[1], b: INDIGO[2], a: 184 }
    args.outputs.labels << { x: 640, y: 408, text: "Video Ended",
                             size_px: 96, font: FONT_DISPLAY,
                             r: PAPER[0], g: PAPER[1], b: PAPER[2],
                             anchor_x: 0.5, anchor_y: 0.5 }
    # 5px red rule under the headline — the one bit of color on the dim.
    args.outputs.solids << { x: 640 - 210, y: 350, w: 420, h: 5,
                             r: RED[0], g: RED[1], b: RED[2] }
    args.outputs.labels << { x: 640, y: 318, text: "↺ Replay · press R",
                             size_px: 22, font: FONT_MONO,
                             r: FAINT_INK[0], g: FAINT_INK[1], b: FAINT_INK[2],
                             anchor_x: 0.5, anchor_y: 0.5 }
  end

  # Beat the final level → "Course Complete": the celebratory counterpart to Video
  # Ended. Indigo dim, the Archivo Black headline in paper over a green rule, then a
  # spinner + line while the page redirects to the certificate.
  def draw_course_complete(args)
    args.outputs.solids << { x: 0, y: 0, w: SCREEN_W, h: SCREEN_H,
                             r: INDIGO[0], g: INDIGO[1], b: INDIGO[2], a: 184 }
    args.outputs.labels << { x: 640, y: 430, text: "Course Complete",
                             size_px: 84, font: FONT_DISPLAY,
                             r: PAPER[0], g: PAPER[1], b: PAPER[2],
                             anchor_x: 0.5, anchor_y: 0.5 }
    args.outputs.solids << { x: 640 - 210, y: 372, w: 420, h: 5,
                             r: GREEN[0], g: GREEN[1], b: GREEN[2] }
    Ui::Spinner.new(args).draw(640, 320, PAPER)
    args.outputs.labels << { x: 640, y: 270, text: "loading your certificate...",
                             size_px: 22, font: FONT_MONO,
                             r: FAINT_INK[0], g: FAINT_INK[1], b: FAINT_INK[2],
                             anchor_x: 0.5, anchor_y: 0.5 }
  end

  # The semantic color for a pending challenge kind (matches the HTML toasts).
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

  # POST to the Rails app so it can broadcast a message to the page. Same-origin,
  # so the session cookie identifies the player; the body is empty but the API
  # wants form-encoded content.
  def report_collision(args, kind)
    args.state.collision_request = DR.http_post(
      start_url(args, kind),
      {},
      [ "Content-Type: application/x-www-form-urlencoded" ]
    )
  end

  # Tell the Rails app the player cleared a level (records progress + grants its
  # achievement). The level goes in the query string, not the body: DR.http_post
  # sends a Hash body as multipart, which Rails won't parse under our urlencoded
  # header, so params[:level] would arrive empty (→ 0).
  def report_level_complete(args, level)
    args.state.level_complete_request = DR.http_post(
      "#{levels_complete_url(args)}?level=#{level}",
      {},
      [ "Content-Type: application/x-www-form-urlencoded" ]
    )
  end

  def report_now_playing(args, level)
    args.state.now_playing_request = DR.http_post(
      "#{levels_playing_url(args)}?level=#{level}",
      {},
      [ "Content-Type: application/x-www-form-urlencoded" ]
    )
  end

  # Poll /games/<kind>/status (~twice a second) while frozen; unfreeze once the
  # server reports the lock cleared (the page completed the pending re-auth).
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

  # Reset the player/camera to the level's start, so it doesn't inherit the previous
  # level's right-edge x and load already-cleared.
  def setup_level(args)
    args.state.player.x = args.state.level.start_x
    args.state.camera_x = 0
    args.state.level.setup(args)
  end

  # The final level is cleared: report it (the server records the win, grants the
  # Graduate achievement, and broadcasts a redirect that sends the page to the
  # certificate), then freeze on the completion card. Fire-and-forget — we never poll
  # the handle (the page redirects away), and not stashing it in args.state keeps the
  # per-tick state export clean once `beaten` stops the world updating. Reported once.
  def beat_game(args)
    return if args.state.beaten
    args.state.beaten = true
    DR.http_post(
      "#{levels_complete_url(args)}?level=#{args.state.level.number}",
      {},
      [ "Content-Type: application/x-www-form-urlencoded" ]
    )
  end

  # The active stage is cleared: report it to the server, then swap in the level it
  # hands off to and seed that scene. The player keeps its hearts.
  def advance_level(args)
    report_level_complete(args, args.state.level.number)
    args.state.level = args.state.level.next_level
    setup_level(args)
    begin_level_intro(args)
    report_now_playing(args, args.state.level.number)
  end

  # Stamp the tick a level begins: the intro card shows (and the world freezes) for
  # the next LEVEL_INTRO_TICKS frames, and the level's countdown runtime starts here.
  def begin_level_intro(args)
    args.state.level.begin_clock(args.state.tick_count)
  end

  # An in-level dialogue holds the world frozen after the intro card fades, while a
  # message is pending — front-loaded at the level's start, or surfaced at a gameplay
  # beat (the welcome level). #current_dialogue is nil when nothing is pending.
  def dialogue_active?(args)
    args.state.started && !State.intro_active?(args) &&
      !args.state.player.game_over && !args.state.level.current_dialogue(args).nil?
  end

  # Replay from the "Video Ended" card: reset the player and scene back to the
  # level this run began on (where their progress resumes, or a level they
  # picked from the playlist) and re-seed it. The poster is skipped (the run is
  # already "playing" — they pressed Replay), so play resumes immediately.
  def restart_run(args)
    args.state.player = Player.new
    args.state.level = Level.build(args.state.start_level || 0)
    setup_level(args)
    begin_level_intro(args)
    report_now_playing(args, args.state.level.number)
  end

  def start_url(args, kind) = "#{Network.base_url(args)}/games/#{kind}/start"
  def status_url(args, kind) = "#{Network.base_url(args)}/games/#{kind}/status"
  def levels_complete_url(args) = "#{Network.base_url(args)}/games/levels/complete"
  def levels_playing_url(args) = "#{Network.base_url(args)}/games/levels/playing"
end
