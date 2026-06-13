require "app/constants.rb"
require "app/entities/player.rb"
require "app/entities/enemy.rb"
require "app/entities/enemies/totp.rb"
require "app/entities/enemies/passkey.rb"
require "app/entities/enemies/password.rb"

# SCREEN_* is the viewport the world scrolls under (WORLD_W/GROUND_Y live in
# app/constants.rb — shared with the entities and their unit tests).
SCREEN_W = 1280
SCREEN_H = 720

PLATFORM_H = 30

# Reachable one-way ledge tops: ~290px apex from the ground reaches the low
# tier; the higher tiers are reachable by hopping up off a lower ledge.
PLATFORM_TIERS = [ 250, 330, 410 ]
PLATFORM_COUNT = 9

module Main
  def tick(args)
    args.state.player ||= Player.new

    # Stationary enemies scattered across the world; walk into one to collide.
    # Each carries its own auth kind (which re-auth flow it triggers) and its own
    # colliding flag so contact fires once per enemy.
    args.state.enemies ||= Enemy.spawn_random
    args.state.platforms ||= generate_platforms

    # Fetch the logged-in user's name once from the Rails app. Same-origin, so the
    # session cookie rides along and /play/me answers as the current user.
    args.state.username ||= 'there'
    if !args.state.name_request
      args.state.name_request = DR.http_get(me_url(args))
    end

    if args.state.name_request != :done && args.state.name_request[:complete]
      request = args.state.name_request
      if request[:http_response_code] == 200
        data = DR.parse_json(request[:response_data])
        args.state.username = data["username"] if data && data["username"]
      end
      # Replace the (non-serializable) response object with a plain marker so the
      # per-tick state export doesn't choke on it and we don't re-fetch.
      args.state.name_request = :done
    end

    # Input, jumping, gravity, and platform/ground collision (frozen while
    # locked) — all owned by the player.
    args.state.player.update(args)

    # Horizontal camera: keep the player centered, clamped to the world edges.
    args.state.camera_x =
      (args.state.player.x + args.state.player.w / 2 - SCREEN_W / 2)
        .clamp(0, WORLD_W - SCREEN_W)

    # Patrol: each enemy paces within its region. Keeps going while the player is
    # locked mid re-auth — only the player freezes — and stops only on game-over.
    args.state.enemies.each { |enemy| enemy.update if enemy.alive } unless args.state.player.game_over

    # Keyboard melee: while the player is mid-swing, any alive enemy overlapping
    # the keyboard hitbox is defeated outright — no heart loss, no re-auth. Runs
    # before the body-collision loop, so a defeated enemy (alive=false) is already
    # skipped there and can't also trigger the lock flow this tick.
    if args.state.player.swing_ticks_left.positive? &&
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

    # Only poll once the collision POST has landed, so a status check can't beat
    # the server flag. Drop the (non-serializable) handle so state export works.
    if args.state.collision_request &&
       args.state.collision_request != :pending &&
       args.state.collision_request[:complete]
      args.state.collision_request = nil
      args.state.player.lock_confirmed = true
    end

    poll_unlock(args) if args.state.player.locked && args.state.player.lock_confirmed

    cam = args.state.camera_x

    # Sky and ground are flat and uniform, so they fill the viewport directly
    # (no camera offset needed).
    args.outputs.solids << { x: 0, y: 0, w: SCREEN_W, h: SCREEN_H, r: 135, g: 206, b: 235 }
    args.outputs.solids << { x: 0, y: 0, w: SCREEN_W, h: GROUND_Y, r: 83, g: 138, b: 64 }

    # World entities are in world coords; subtract the camera offset to draw.
    args.state.platforms.each do |plat|
      args.outputs.solids << { x: plat.x - cam, y: plat.y, w: plat.w, h: plat.h,
                               r: 120, g: 85, b: 50 }
    end

    args.state.enemies.each { |enemy| enemy.render(args, cam) if enemy.alive }

    args.state.player.render(args, cam)

    draw_hearts(args)

    args.outputs.labels << { x: 640,
                             y: 680,
                             text: "Hello, #{args.state.username}!",
                             size_px: 30,
                             anchor_x: 0.5,
                             anchor_y: 0.5 }

    if args.state.player.game_over
      draw_game_over(args)
    else
      draw_hint(args)
    end
  end

  # Three heart slots in the top-left: full alpha for hearts the player still has,
  # dimmed for the ones they've lost.
  def draw_hearts(args)
    Player::MAX_HEARTS.times do |i|
      args.outputs.sprites << { x: 20 + i * 40,
                                y: SCREEN_H - 52,
                                w: 32,
                                h: 32,
                                path: "sprites/ui/heart.png",
                                a: i < args.state.player.hearts ? 255 : 60 }
    end
  end

  # Dim the scene and announce the run is over (the player is frozen).
  def draw_game_over(args)
    args.outputs.solids << { x: 0, y: 0, w: SCREEN_W, h: SCREEN_H, r: 0, g: 0, b: 0, a: 150 }
    args.outputs.labels << { x: 640,
                             y: 360,
                             text: "Game Over",
                             size_px: 60,
                             r: 255, g: 255, b: 255,
                             anchor_x: 0.5,
                             anchor_y: 0.5 }
  end

  def draw_hint(args)
    hint = if !args.state.player.locked
      "(arrow keys or A/D to move, space to jump, click to swing)"
    elsif args.state.player.pending_challenge == :passkey
      "You bumped the passkey enemy! Use the passkey toast to continue."
    elsif args.state.player.pending_challenge == :password
      "You bumped the password enemy! Enter your password in the toast to continue."
    else
      "You bumped the enemy! Enter your TOTP code in the toast to continue."
    end

    args.outputs.labels << { x: 640,
                             y: 640,
                             text: hint,
                             size_px: 20,
                             anchor_x: 0.5,
                             anchor_y: 0.5 }
  end

  # Scatter one-way ledges across the world, one per evenly spaced slot (so they
  # spread out instead of clumping) with a random width and a random reachable
  # tier height. Generated once per run.
  def generate_platforms
    slot = (WORLD_W - 400) / PLATFORM_COUNT
    PLATFORM_COUNT.times.map do |i|
      w = 180 + rand(100)
      x = 200 + i * slot + rand([ slot - w, 0 ].max)
      top = PLATFORM_TIERS.sample
      { x: x, y: top - PLATFORM_H, w: w, h: PLATFORM_H }
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
end
