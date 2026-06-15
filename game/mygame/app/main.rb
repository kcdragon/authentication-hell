require "app/constants.rb"
require "app/entities/player.rb"
require "app/entities/enemy.rb"
require "app/entities/platform.rb"
require "app/entities/heart_pickup.rb"
require "app/entities/enemies/totp.rb"
require "app/entities/enemies/passkey.rb"
require "app/entities/enemies/password.rb"
require "app/levels/level.rb"
require "app/levels/00_tutorial.rb"
require "app/levels/01_main.rb"
require "app/levels/02_gauntlet.rb"

module Main
  def tick(args)
    args.state.player ||= Player.new

    # The game opens on the tutorial level (one password enemy on flat ground) and
    # hands off to the main world once the player clears it. args.state.level always
    # holds the active level (a TutorialLevel, then a MainLevel) — unset only on the
    # very first tick. Each enemy carries its own auth kind (which re-auth flow it
    # triggers) and its own colliding flag so contact fires once per enemy.
    # A default scene so rendering has something to draw behind the poster; the
    # real starting level arrives from /play/me below and swaps in before play
    # begins (the poster is gated on that response).
    args.state.start_level ||= 0
    unless args.state.level
      args.state.level = TutorialLevel.new
      args.state.level.setup(args)
    end

    # Fetch the logged-in user's name and starting level once from the Rails app.
    # Same-origin, so the session cookie rides along and /play/me answers as the
    # current user (start_level = where their progress resumes, or a level they
    # just clicked in the playlist).
    args.state.username ||= 'there'
    if !args.state.me_request
      args.state.me_request = DR.http_get(me_url(args))
    end

    if args.state.me_request != :done && args.state.me_request[:complete]
      request = args.state.me_request
      if request[:http_response_code] == 200
        data = DR.parse_json(request[:response_data])
        if data
          args.state.username = data["username"] if data["username"]
          # Swap to the resolved starting level before the run begins (the loading
          # screen covers the play area until now, so this is invisible) and report
          # it as now playing.
          if data["start_level"] && !args.state.started
            args.state.start_level = data["start_level"]
            if args.state.level.number != args.state.start_level
              args.state.level = Level.build(args.state.start_level)
              args.state.level.setup(args)
            end
            report_now_playing(args, args.state.start_level)
          end
        end
      end
      # Replace the (non-serializable) response object with a plain marker so the
      # per-tick state export doesn't choke on it and we don't re-fetch.
      args.state.me_request = :done
    end

    # The "fake training video" frame: the game opens paused on a poster with a
    # giant play button, as if a corporate-training clip hasn't started. The world
    # stays frozen until the player presses play; everything below runs only once
    # the run has begun (started), except rendering, which always draws so the
    # poster is visible.
    if !args.state.started
      handle_poster_input(args)
    else
      toggled = handle_pause_input(args)
      update_world(args) unless args.state.paused || toggled
    end

    render_world(args)
  end

  # While paused on the poster, a click or space "presses play" and starts the run
  # — but only once /play/me has resolved, so we never start on the wrong level
  # while the starting level is still in flight (a fast, same-origin call).
  def handle_poster_input(args)
    return unless args.state.me_request == :done

    if args.inputs.mouse.click || args.inputs.keyboard.key_down.space
      args.state.started = true
    end
  end

  # Pause / resume mid-run via the Escape key or a click on the play/pause button
  # (the only wired transport control). Disallowed while the run is over or buffering
  # a re-auth: there's nothing to pause there, and pausing a lock would stall the
  # unlock poll. Returns whether it toggled this tick so the caller can skip the world
  # update — the same click then won't also swing the keyboard.
  def handle_pause_input(args)
    return false if args.state.player.game_over || args.state.player.locked

    toggle = args.inputs.keyboard.key_down.escape ||
             (args.inputs.mouse.click && args.inputs.mouse.point.inside_rect?(PLAY_BUTTON))
    args.state.paused = !args.state.paused if toggle
    !!toggle
  end

  # One tick of live gameplay (only while the run is started and not over).
  def update_world(args)
    # Input, jumping, gravity, and platform/ground collision (frozen while
    # locked) — all owned by the player.
    args.state.player.update(args)

    # Horizontal camera: keep the player centered, clamped to the world edges.
    args.state.camera_x =
      (args.state.player.x + args.state.player.w / 2 - SCREEN_W / 2)
        .clamp(0, args.state.level.world_w - SCREEN_W)

    # Per-tick level scripting (e.g. the tutorial spawns its enemy once the player
    # has jumped onto the platform). Reads the camera set just above.
    args.state.level.update(args)

    # Patrol: each enemy paces within its region. Keeps going while the player is
    # locked mid re-auth — only the player freezes — and stops only on game-over.
    args.state.enemies.each { |enemy| enemy.update if enemy.alive } unless args.state.player.game_over

    # Keyboard melee: while the player is mid-swing, any alive enemy overlapping
    # the keyboard hitbox is defeated outright — no heart loss, no re-auth. Runs
    # before the body-collision loop, so a defeated enemy (alive=false) is already
    # skipped there and can't also trigger the lock flow this tick.
    if args.state.level.melee? &&
       args.state.player.swing_ticks_left.positive? &&
       !args.state.player.locked && !args.state.player.game_over
      hitbox = args.state.player.keyboard_hitbox
      args.state.enemies.each do |enemy|
        next unless enemy.alive

        enemy.alive = false if args.geometry.intersect_rect?(hitbox, enemy.hitbox)
      end
    end

    # Fire once on contact (the transition, not every overlapping frame): dock a
    # heart, retire the enemy for good, then either game-over (last heart) or kick
    # off that enemy's auth flow and freeze the player.
    args.state.enemies.each do |enemy|
      next unless enemy.alive

      colliding = args.geometry.intersect_rect?(enemy.hitbox, args.state.player)
      if colliding && !enemy.colliding
        args.state.player.hearts -= 1
        enemy.alive = false
        if args.state.player.hearts <= 0
          # Losing the last heart ends the run; skip the re-auth (nothing to unlock).
          args.state.player.game_over = true
        else
          report_collision(args, enemy.auth)
          args.state.player.locked = true
          args.state.player.pending_challenge = enemy.auth
        end
      end
      enemy.colliding = colliding
    end unless args.state.player.game_over

    # Walking into a heal heart restores one heart (capped) and retires the pickup;
    # the level decides what that means (the tutorial counts it as cleared).
    args.state.collectables.each do |pickup|
      next unless pickup.alive
      next unless args.geometry.intersect_rect?(pickup.hitbox, args.state.player)

      pickup.alive = false
      args.state.player.hearts = [ args.state.player.hearts + 1, Player::MAX_HEARTS ].min
      args.state.level.on_collect(args)
    end unless args.state.player.game_over

    # Hand off once the active stage reports its goal met (e.g. the tutorial after
    # the heal). Endless stages never complete, so this is a no-op there.
    advance_level(args) if args.state.level.complete?

    # Only poll once the collision POST has landed, so a status check can't beat
    # the server flag. Drop the (non-serializable) handle so state export works.
    if args.state.collision_request &&
       args.state.collision_request != :pending &&
       args.state.collision_request[:complete]
      args.state.collision_request = nil
      args.state.player.lock_confirmed = true
    end

    # Fire-and-forget level report: drop the (non-serializable) handle once it
    # lands so the per-tick state export doesn't choke on it.
    if args.state.level_complete_request && args.state.level_complete_request[:complete]
      args.state.level_complete_request = nil
    end

    poll_unlock(args) if args.state.player.locked && args.state.player.lock_confirmed

    # On game over the run can be restarted from the "Video Ended" card.
    restart_run(args) if args.state.player.game_over && args.inputs.keyboard.key_down.r
  end

  # Draw the whole frame: the warm-paper playfield, the world entities, then the
  # video-player chrome (control bar / scrubber / HUD) over it, then the active
  # overlay (poster, buffering, or the game-over card).
  def render_world(args)
    # camera_x is set by update_world, which is gated behind `started` — so on the
    # poster frames before play begins it's still unset. Default to 0 so rendering
    # always has a numeric camera.
    cam = args.state.camera_x ||= 0

    # Clear the whole window — including the letterbox outside the 1280x720 safe
    # area — to the paper color, so the bars blend into the surrounding page
    # instead of reading as black.
    args.outputs.background_color = PAPER

    # Warm paper wall fills the viewport; the control bar (= floor) is drawn by
    # draw_control_bar below, so its top edge reads as the ground line.
    args.outputs.solids << { x: 0, y: 0, w: SCREEN_W, h: SCREEN_H,
                             r: PAPER[0], g: PAPER[1], b: PAPER[2] }

    # Until /play/me answers we don't yet know the starting level, so the world
    # below is a placeholder that may swap. Draw the video chrome with a loading
    # state instead of the (wrong) level, so the level never visibly switches.
    if args.state.me_request != :done
      draw_control_bar(args)
      draw_loading(args)
      return
    end

    # World entities are in world coords; each subtracts the camera offset to draw.
    args.state.platforms.each { |plat| plat.render(args, cam) }

    args.state.enemies.each { |enemy| enemy.render(args, cam) if enemy.alive }

    args.state.collectables.each { |pickup| pickup.render(args, cam) if pickup.alive }

    args.state.player.render(args, cam)

    # Video-player chrome over the world: the dark control bar (its lip is the
    # floor line), the scrubber driven by world progress, and the HUD hearts.
    draw_control_bar(args)
    draw_hearts(args)

    if !args.state.started
      draw_poster(args)
    elsif args.state.player.game_over
      draw_video_ended(args)
    elsif args.state.player.locked
      draw_buffering(args)
    elsif args.state.paused
      draw_paused(args)
    else
      args.state.level.draw(args)
    end
  end

  # Fraction of the current level the player has crossed (0..1) — drives the
  # scrubber fill and the faux timestamp, both measured against the active level's
  # width so a short stage (the tutorial) fills its own short "video."
  def progress(args)
    (args.state.player.x.to_f / (args.state.level.world_w - Player::WIDTH)).clamp(0.0, 1.0)
  end

  # The faux runtime (seconds) of the current level's "video": VIDEO_SECONDS is the
  # full world's length, scaled by the level's width so the timestamp's total tracks
  # how big the level is (the one-screen tutorial reads as a much shorter clip).
  def video_seconds(args)
    VIDEO_SECONDS * args.state.level.world_w / WORLD_W
  end

  # m:ss for a number of seconds.
  def timecode(seconds)
    total = seconds.round
    format("%d:%02d", total / 60, total % 60)
  end

  # The bottom control bar doubles as the floor: a dark indigo band filling
  # everything below the floor line (GROUND_Y), with a lighter lip on top that the
  # player visibly stands on. Holds the scrubber and the playback controls so the
  # whole thing reads as a video player's transport.
  def draw_control_bar(args)
    args.outputs.solids << { x: 0, y: 0, w: SCREEN_W, h: BAR_TOP,
                             r: INDIGO[0], g: INDIGO[1], b: INDIGO[2] }
    args.outputs.solids << { x: 0, y: BAR_TOP - 3, w: SCREEN_W, h: 3,
                             r: INDIGO_LIP[0], g: INDIGO_LIP[1], b: INDIGO_LIP[2] }

    draw_scrubber(args)
    draw_transport(args)
  end

  # The scrubber: a track, a cosmetic "buffered" bar running ahead of progress (so
  # it always looks like a video pre-loading), the green progress fill, and a
  # playhead handle. The handle goes red and stops advancing on game over; on a
  # collision it stalls and rings in the enemy's color (handled by the caller's
  # state — here it just reflects progress).
  def draw_scrubber(args)
    frac = progress(args)
    track_y = SCRUBBER_Y

    args.outputs.solids << { x: SCRUBBER_X, y: track_y, w: SCRUBBER_W, h: SCRUBBER_H,
                             r: INDIGO_LIP[0], g: INDIGO_LIP[1], b: INDIGO_LIP[2] }

    buffered = (frac + 0.22).clamp(0.0, 1.0)
    args.outputs.solids << { x: SCRUBBER_X, y: track_y, w: SCRUBBER_W * buffered, h: SCRUBBER_H,
                             r: MUTED[0], g: MUTED[1], b: MUTED[2] }

    args.outputs.solids << { x: SCRUBBER_X, y: track_y, w: SCRUBBER_W * frac, h: SCRUBBER_H,
                             r: GREEN[0], g: GREEN[1], b: GREEN[2] }

    # Playhead: paper-white normally, red once the "video" has ended.
    handle_color = args.state.player.game_over ? RED : CARD
    hx = SCRUBBER_X + SCRUBBER_W * frac
    args.outputs.solids << { x: hx - 8, y: track_y + SCRUBBER_H / 2 - 8, w: 16, h: 16,
                             r: INDIGO[0], g: INDIGO[1], b: INDIGO[2] }
    args.outputs.solids << { x: hx - 6, y: track_y + SCRUBBER_H / 2 - 6, w: 12, h: 12,
                             r: handle_color[0], g: handle_color[1], b: handle_color[2] }
  end

  # The transport row: a play/pause button on the left and the faux timestamp next
  # to it, plus the usual CC / speed / fullscreen affordances on the right — all
  # static (the buttons aren't wired; they only sell the video-player disguise).
  def draw_transport(args)
    # Play/pause button (blue, paper glyph). Shows the pause bars while playing and
    # a play triangle when the run is paused, hasn't started, or has ended.
    bx = PLAY_BUTTON[:x]
    by = PLAY_BUTTON[:y]
    args.outputs.solids << { **PLAY_BUTTON, r: BLUE[0], g: BLUE[1], b: BLUE[2] }
    playing = args.state.started && !args.state.player.game_over &&
              !args.state.player.locked && !args.state.paused
    if playing
      args.outputs.solids << { x: bx + 11, y: by + 9, w: 4, h: 16, r: PAPER[0], g: PAPER[1], b: PAPER[2] }
      args.outputs.solids << { x: bx + 19, y: by + 9, w: 4, h: 16, r: PAPER[0], g: PAPER[1], b: PAPER[2] }
    else
      args.outputs.solids << { x: bx + 12, y: by + 9, x2: bx + 12, y2: by + 25,
                               x3: bx + 26, y3: by + 17,
                               r: PAPER[0], g: PAPER[1], b: PAPER[2] }
    end

    frac = progress(args)
    runtime = video_seconds(args)
    args.outputs.labels << { x: bx + 48, y: by + 26,
                             text: "#{timecode(frac * runtime)} / #{timecode(runtime)}",
                             size_px: 22, font: FONT_MONO,
                             r: TS_INK[0], g: TS_INK[1], b: TS_INK[2],
                             anchor_x: 0, anchor_y: 1 }

    args.outputs.labels << { x: SCREEN_W - SCRUBBER_X, y: by + 26,
                             text: "CC   1.0×   ⛶",
                             size_px: 20, font: FONT_MONO,
                             r: FAINT_INK[0], g: FAINT_INK[1], b: FAINT_INK[2],
                             anchor_x: 1, anchor_y: 1 }
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

  # The poster / paused start state: a scrim over the play area lifts a giant blue
  # play button (the site's primary action) with a true-black ink border + hard
  # offset shadow, plus the "AUTHENTICATION 101" title card. Clicking (or space)
  # "presses play" and starts the run — see handle_poster_input.
  def draw_poster(args)
    # Scrim over the play area only (above the control bar), so the transport stays
    # crisp underneath.
    args.outputs.solids << { x: 0, y: BAR_TOP, w: SCREEN_W, h: SCREEN_H - BAR_TOP,
                             r: PAPER[0], g: PAPER[1], b: PAPER[2], a: 90 }

    cx = 640
    cy = 392
    size = 128
    # Hard offset shadow, then the ink border, then the blue button face.
    args.outputs.solids << { x: cx - size / 2 + 9, y: cy - size / 2 - 9, w: size, h: size,
                             r: INK[0], g: INK[1], b: INK[2] }
    args.outputs.solids << { x: cx - size / 2, y: cy - size / 2, w: size, h: size,
                             r: INK[0], g: INK[1], b: INK[2] }
    args.outputs.solids << { x: cx - size / 2 + 4, y: cy - size / 2 + 4, w: size - 8, h: size - 8,
                             r: BLUE[0], g: BLUE[1], b: BLUE[2] }
    # Play triangle (paper), nudged right to optically center. A solid-color
    # triangle is a three-point entry on outputs.solids (x/y, x2/y2, x3/y3).
    args.outputs.solids << { x: cx - 18, y: cy + 30, x2: cx - 18, y2: cy - 30,
                             x3: cx + 32, y3: cy,
                             r: PAPER[0], g: PAPER[1], b: PAPER[2] }

    args.outputs.labels << { x: cx, y: cy - 104, text: "AUTHENTICATION 101",
                             size_px: 30, font: FONT_DISPLAY,
                             r: INK[0], g: INK[1], b: INK[2],
                             anchor_x: 0.5, anchor_y: 0.5 }
    args.outputs.labels << { x: cx, y: cy - 140, text: "click play to begin onboarding",
                             size_px: 18, font: FONT_MONO,
                             r: MUTED[0], g: MUTED[1], b: MUTED[2],
                             anchor_x: 0.5, anchor_y: 0.5 }
  end

  # Shown while /play/me is still in flight: the same "AUTHENTICATION 101" card as
  # the poster, but with a spinner where the play button will land, so the poster
  # appears already on the correct level instead of swapping the world in view.
  def draw_loading(args)
    cx = 640
    cy = 392
    draw_spinner(args, cx, cy, BLUE)

    args.outputs.labels << { x: cx, y: cy - 104, text: "AUTHENTICATION 101",
                             size_px: 30, font: FONT_DISPLAY,
                             r: INK[0], g: INK[1], b: INK[2],
                             anchor_x: 0.5, anchor_y: 0.5 }
    args.outputs.labels << { x: cx, y: cy - 140, text: "loading…",
                             size_px: 18, font: FONT_MONO,
                             r: MUTED[0], g: MUTED[1], b: MUTED[2],
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
                 "Space    jump",
                 "Click    swing" ]
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
  # A faint full ring with a colored arc that rotates over time, centered on cx/cy.
  def draw_spinner(args, cx, cy, color)
    spin = (args.state.tick_count % 60) * 6
    8.times do |i|
      ang = (spin + i * 45) * Math::PI / 180
      bx = cx + Math.cos(ang) * 26
      by = cy + Math.sin(ang) * 26
      lead = i >= 6
      args.outputs.solids << { x: bx - 3, y: by - 3, w: 6, h: 6,
                               r: lead ? color[0] : 217, g: lead ? color[1] : 205, b: lead ? color[2] : 176 }
    end
  end

  def draw_buffering(args)
    color = challenge_color(args.state.player.pending_challenge)

    draw_spinner(args, 640, 470, color)

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

  # The semantic color for a pending challenge kind (matches the HTML toasts).
  def challenge_color(kind)
    case kind
    when :passkey then BLUE
    when :password then AMBER
    else PURPLE
    end
  end

  # POST to the Rails app so it can broadcast a message to the page. Same-origin,
  # so the session cookie identifies the player; the body is empty but the API
  # wants form-encoded content.
  def report_collision(args, kind)
    args.state.collision_request = :pending
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

  # The active stage is cleared: report it to the server, then swap in the level it
  # hands off to and seed that scene. The player keeps its position and hearts.
  def advance_level(args)
    report_level_complete(args, args.state.level.number)
    args.state.level = args.state.level.next_level
    args.state.level.setup(args)
    report_now_playing(args, args.state.level.number)
  end

  # Replay from the "Video Ended" card: reset the player and scene back to the
  # level this run began on (where their progress resumes, or a level they
  # picked from the playlist) and re-seed it. The poster is skipped (the run is
  # already "playing" — they pressed Replay), so play resumes immediately.
  def restart_run(args)
    args.state.player = Player.new
    args.state.level = Level.build(args.state.start_level || 0)
    args.state.level.setup(args)
    args.state.camera_x = 0
    report_now_playing(args, args.state.level.number)
  end

  # The Rails server's origin (scheme + host[:port]), baked into the bundle by
  # bin/build-game — the production domain in a deploy build, else the local dev
  # server. Falls back to http://localhost:3000 when the file is absent, e.g. a
  # native `./dragonruby mygame` run that never went through build-game. Read
  # once, then memoized for the rest of the session.
  def server_base(args)
    args.state.server_base ||= (args.gtk.read_file("app/server_config.txt") || "http://localhost:3000").strip
  end

  def me_url(args) = "#{server_base(args)}/play/me"
  def start_url(args, kind) = "#{server_base(args)}/games/#{kind}/start"
  def status_url(args, kind) = "#{server_base(args)}/games/#{kind}/status"
  def levels_complete_url(args) = "#{server_base(args)}/games/levels/complete"
  def levels_playing_url(args) = "#{server_base(args)}/games/levels/playing"
end
