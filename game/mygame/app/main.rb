require "app/constants.rb"
require "app/caption.rb"
require "app/entities/player.rb"
require "app/entities/enemy.rb"
require "app/entities/platform.rb"
require "app/entities/hole.rb"
require "app/entities/heart_pickup.rb"
require "app/entities/password_character.rb"
require "app/entities/certificate.rb"
require "app/entities/enemies/totp.rb"
require "app/entities/enemies/passkey.rb"
require "app/entities/enemies/password.rb"
require "app/levels/level.rb"
require "app/levels/00_tutorial.rb"
require "app/levels/01_password.rb"
require "app/levels/02_main.rb"
require "app/levels/03_gauntlet.rb"

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
    args.state.captions_on = true if args.state.captions_on.nil?
    unless args.state.level
      args.state.level = TutorialLevel.new
      setup_level(args)
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
              setup_level(args)
            end
            report_now_playing(args, args.state.start_level)
          end
        end
      end
      # Replace the (non-serializable) response object with a plain marker so the
      # per-tick state export doesn't choke on it and we don't re-fetch.
      args.state.me_request = :done
    end

    # The run begins automatically once /play/me has resolved (the player already
    # pressed ▶ Play on the site to load the game, so there's no in-canvas poster).
    # The loading spinner covers the brief wait; then the first level's intro card
    # plays. Everything below runs only once the run has begun (started).
    cc_clicked = handle_caption_input(args)
    start_run(args) if !args.state.started && args.state.me_request == :done
    if args.state.started
      toggled = handle_pause_input(args)
      # The world stays frozen behind the intro card so a level start (and the
      # player's reset to the new scene's left edge) lands while it's covered.
      update_world(args) unless args.state.paused || toggled || cc_clicked || level_intro_active?(args)
    end

    render_world(args)
  end

  # Kick off the run: the first level's intro card plays, then the world unfreezes.
  def start_run(args)
    args.state.started = true
    begin_level_intro(args)
  end

  # Pause / resume mid-run via the Escape key or a click on the play/pause button
  # (the only wired transport control). Disallowed while the run is over or buffering
  # a re-auth: there's nothing to pause there, and pausing a lock would stall the
  # unlock poll. Returns whether it toggled this tick so the caller can skip the world
  # update on the frame the player clicks pause.
  def handle_pause_input(args)
    return false if args.state.player.game_over || args.state.player.locked

    toggle = args.inputs.keyboard.key_down.escape ||
             (args.inputs.mouse.click && args.inputs.mouse.point.inside_rect?(PLAY_BUTTON))
    args.state.paused = !args.state.paused if toggle
    !!toggle
  end

  # Toggle closed-captions on a click of the CC button. Wired in every state (it's
  # player chrome, not gameplay) and returns whether it consumed the click, so the
  # same click won't also press play on the poster.
  def handle_caption_input(args)
    hit = args.inputs.mouse.click && args.inputs.mouse.point.inside_rect?(CC_BUTTON)
    args.state.captions_on = !args.state.captions_on if hit
    !!hit
  end

  # One tick of live gameplay (only while the run is started and not over).
  def update_world(args)
    # Input, jumping, gravity, and platform/ground collision (frozen while
    # locked) — all owned by the player.
    args.state.player.update(args)

    # A pit-fall: the player walked off a gap in the ground and dropped through.
    handle_hole_fall(args) unless args.state.player.game_over

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

    # Fire once on contact (the transition, not every overlapping frame). Coming
    # down on top of an enemy stomps it — defeated outright, no heart loss, and
    # the player bounces up (gated on melee?, so the tutorial's re-auth lesson
    # still forces the challenge). Otherwise it's a side/ground hit:
    # dock a heart, retire the enemy, then either game-over (last heart) or kick
    # off that enemy's auth flow and freeze the player.
    args.state.enemies.each do |enemy|
      next unless enemy.alive

      colliding = args.geometry.intersect_rect?(enemy.hitbox, args.state.player)
      if colliding && !enemy.colliding
        if args.state.level.melee? && args.state.player.stomping?(enemy)
          enemy.alive = false
          args.state.player.bounce
        else
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
      end
      enemy.colliding = colliding
    end unless args.state.player.game_over

    # Walking into a collectable retires the pickup and applies its own effect (a
    # heart heals, a password character is recorded); the level then decides what
    # that means (the tutorial counts the heal as cleared).
    args.state.collectables.each do |pickup|
      next unless pickup.alive
      next unless args.geometry.intersect_rect?(pickup.hitbox, args.state.player)

      pickup.alive = false
      pickup.collect(args)
      args.state.level.on_collect(args)
    end unless args.state.player.game_over

    # Hand off once the active stage reports its goal met (e.g. the tutorial after
    # the heal). Endless stages never complete, so this is a no-op there.
    advance_level(args) if args.state.level.complete?

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
      player.game_over = true
    else
      cx = player.x + player.w / 2
      # The nearest gap at or left of the center: they may have drifted past its
      # right edge while falling, so a containment check could miss the pit they
      # actually fell through.
      hole = (args.state.holes || []).select { |h| h.x <= cx }.max_by(&:x)
      back = (hole ? hole.x : player.x) - HOLE_RESPAWN_BACK
      player.x = back.clamp(0, args.state.level.world_w - Player::WIDTH)
      player.y = GROUND_Y
      player.vy = 0
      player.grounded = true
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

    # Keep the whole scene (platforms, enemies, collectables, player) hidden behind
    # the intro card so the new level only appears once the card has finished fading
    # out — no entities popping in at the scene's start.
    unless level_intro_active?(args)
      # World entities are in world coords; each subtracts the camera offset to draw.
      args.state.platforms.each { |plat| plat.render(args, cam) }

      args.state.enemies.each { |enemy| enemy.render(args, cam) if enemy.alive }

      args.state.collectables.each { |pickup| pickup.render(args, cam) if pickup.alive }

      args.state.player.render(args, cam)
    end

    # Video-player chrome over the world: the dark control bar (its lip is the
    # floor line), the scrubber driven by world progress, and the HUD hearts.
    draw_control_bar(args)
    draw_hearts(args)
    draw_collected_password_characters(args) if args.state.level.password_targets

    if args.state.player.game_over
      draw_video_ended(args)
    elsif args.state.player.locked
      draw_buffering(args)
    elsif args.state.paused
      draw_paused(args)
    elsif level_intro_active?(args)
      draw_level_intro(args)
    else
      # Each level draws its own prompt as the top closed caption (only here, during
      # live play, where a prompt belongs).
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

    # Pits cut through the dark band here — after it's laid down, but before the
    # scrubber/transport, so the controls still draw legibly over a gap. Hidden behind
    # the intro card like the rest of the scene.
    draw_holes(args) unless level_intro_active?(args)

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
    # a play triangle when the run is paused, hasn't started, or has ended. Hidden
    # behind the intro card so the only play affordance before a level is the poster's.
    bx = PLAY_BUTTON[:x]
    by = PLAY_BUTTON[:y]
    unless level_intro_active?(args)
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
    end

    frac = progress(args)
    runtime = video_seconds(args)
    args.outputs.labels << { x: bx + 48, y: by + 26,
                             text: "#{timecode(frac * runtime)} / #{timecode(runtime)}",
                             size_px: 22, font: FONT_MONO,
                             r: TS_INK[0], g: TS_INK[1], b: TS_INK[2],
                             anchor_x: 0, anchor_y: 1 }

    cc_ink = args.state.captions_on ? TS_INK : FAINT_INK
    args.outputs.labels << { x: CC_BUTTON[:x], y: by + 26, text: "CC",
                             size_px: 20, font: FONT_MONO,
                             r: cc_ink[0], g: cc_ink[1], b: cc_ink[2],
                             anchor_x: 0, anchor_y: 1 }
    if args.state.captions_on
      args.outputs.solids << { x: CC_BUTTON[:x], y: by + 6, w: 20, h: 2,
                               r: BLUE[0], g: BLUE[1], b: BLUE[2] }
    end

    args.outputs.labels << { x: SCREEN_W - SCRUBBER_X, y: by + 26, text: "1.0×   ⛶",
                             size_px: 20, font: FONT_MONO,
                             r: FAINT_INK[0], g: FAINT_INK[1], b: FAINT_INK[2],
                             anchor_x: 1, anchor_y: 1 }
  end

  # Each pit breaks the floor in world space; drawn after the control bar so the
  # cutout sits over its lip (entities/hole.rb owns the look).
  def draw_holes(args)
    cam = args.state.camera_x || 0
    (args.state.holes || []).each { |hole| hole.render(args, cam) }
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

  # The password level's tray, just right of the hearts: one slot per character
  # class. A held class shows its collected glyph in a filled amber chip; a missing
  # one shows a faint placeholder glyph of that class, so the player sees what's
  # left to find. Drawn only on a level that declares password_targets.
  PASSWORD_SLOT_HINTS = { upper: "A", lower: "a", digit: "0", symbol: "#" }.freeze
  def draw_collected_password_characters(args)
    held = args.state.player.collected_password_characters
    x0 = 168
    y = SCREEN_H - 61
    w = 38
    h = 34
    args.state.level.password_targets.each_with_index do |klass, i|
      x = x0 + i * 46
      glyph = held[klass]
      args.outputs.solids << { x: x, y: y, w: w, h: h, r: INK[0], g: INK[1], b: INK[2] }
      face = glyph ? AMBER : PAPER
      args.outputs.solids << { x: x + 3, y: y + 3, w: w - 6, h: h - 6,
                               r: face[0], g: face[1], b: face[2] }
      ink = glyph ? INK : FAINT_INK
      args.outputs.labels << { x: x + w / 2, y: y + h / 2 + 1, text: glyph || PASSWORD_SLOT_HINTS[klass],
                               size_px: 22, font: FONT_MONO_B, r: ink[0], g: ink[1], b: ink[2],
                               anchor_x: 0.5, anchor_y: 0.5 }
    end
  end

  # The level-intro "chapter card": a centered neo-brutalist card (ink shadow → ink
  # border → white face, like the captions) with a CHAPTER N eyebrow over the level
  # title, fading the whole card in then out over LEVEL_INTRO_TICKS while the world
  # holds frozen behind it.
  def draw_level_intro(args)
    level = args.state.level
    elapsed = args.state.tick_count - args.state.level_intro_at
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
    w = 520
    h = 152
    left = cx - w / 2
    bottom = cy - h / 2
    accent = level.accent

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
    args.outputs.labels << { x: cx, y: cy - 18, text: level.title,
                             size_px: 40, font: FONT_DISPLAY,
                             r: INK[0], g: INK[1], b: INK[2], a: alpha,
                             anchor_x: 0.5, anchor_y: 0.5 }
  end

  # Shown while /play/me is still in flight: the "AUTHENTICATION 101" title card with
  # a spinner, so the brief wait before the run auto-starts reads as the video
  # buffering on the correct level instead of swapping the world in view.
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

  # The active stage is cleared: report it to the server, then swap in the level it
  # hands off to and seed that scene. The player keeps its hearts.
  def advance_level(args)
    report_level_complete(args, args.state.level.number)
    args.state.level = args.state.level.next_level
    setup_level(args)
    begin_level_intro(args)
    report_now_playing(args, args.state.level.number)
  end

  # Stamp the tick a level begins, so the intro card shows (and the world freezes)
  # for the next LEVEL_INTRO_TICKS frames.
  def begin_level_intro(args) = args.state.level_intro_at = args.state.tick_count

  def level_intro_active?(args)
    args.state.started && args.state.level_intro_at &&
      (args.state.tick_count - args.state.level_intro_at) < LEVEL_INTRO_TICKS
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
