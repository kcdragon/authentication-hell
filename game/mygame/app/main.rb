require "app/entities/player.rb"
require "app/entities/enemy.rb"

SCREEN_W = 1280
SCREEN_H = 720
GROUND_Y = 100

PLATFORM_W = 260
PLATFORM_H = 30
PLATFORM_TOP = 250            # y of the side platforms' top surface
# A higher ledge, 150px above the left platform: out of reach from the ground
# (~290px apex) but reachable by jumping off the left platform (~440px apex).
HIGH_PLATFORM_TOP = 400

# Static one-way ledges. The two side ledges hug the left/right edges; the high
# ledge overlaps the left one so you can hop up onto it from there.
PLATFORMS = [
  { x: 0,                     y: PLATFORM_TOP - PLATFORM_H,      w: PLATFORM_W, h: PLATFORM_H },
  { x: SCREEN_W - PLATFORM_W, y: PLATFORM_TOP - PLATFORM_H,      w: PLATFORM_W, h: PLATFORM_H },
  { x: 180,                   y: HIGH_PLATFORM_TOP - PLATFORM_H, w: PLATFORM_W, h: PLATFORM_H }
]

module Main
  def tick(args)
    args.state.player ||= Player.new

    # Stationary enemies parked off to each side; walk into one to collide. Each
    # carries its own auth kind (which re-auth flow it triggers) and its own
    # colliding flag so contact fires once per enemy.
    args.state.enemies ||= Enemy.spawn_defaults

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

    # Fire once on contact (the transition, not every overlapping frame): report
    # it to that enemy's auth flow, freeze the player, and retire the enemy for good.
    args.state.enemies.each do |enemy|
      next unless enemy.alive

      colliding = args.geometry.intersect_rect?(enemy, args.state.player)
      if colliding && !enemy.colliding
        report_collision(args, enemy.auth)
        args.state.player.locked = true
        args.state.player.pending_challenge = enemy.auth
        enemy.alive = false
      end
      enemy.colliding = colliding
    end

    # Only poll once the collision POST has landed, so a status check can't beat
    # the server flag. Drop the (non-serializable) handle so state export works.
    if args.state.collision_request &&
       args.state.collision_request != :pending &&
       args.state.collision_request[:complete]
      args.state.collision_request = nil
      args.state.player.lock_confirmed = true
    end

    poll_unlock(args) if args.state.player.locked && args.state.player.lock_confirmed

    # Sky background.
    args.outputs.solids << { x: 0, y: 0, w: SCREEN_W, h: SCREEN_H, r: 135, g: 206, b: 235 }

    # Ground.
    args.outputs.solids << { x: 0, y: 0, w: SCREEN_W, h: GROUND_Y, r: 83, g: 138, b: 64 }

    # Platforms.
    PLATFORMS.each do |plat|
      args.outputs.solids << { x: plat.x, y: plat.y, w: plat.w, h: plat.h,
                               r: 120, g: 85, b: 50 }
    end

    # Enemies.
    args.state.enemies.each { |enemy| enemy.render(args) if enemy.alive }

    args.state.player.render(args)

    args.outputs.labels << { x: 640,
                             y: 680,
                             text: "Hello, #{args.state.username}!",
                             size_px: 30,
                             anchor_x: 0.5,
                             anchor_y: 0.5 }

    draw_hint(args)
  end

  def draw_hint(args)
    hint = if !args.state.player.locked
      "(arrow keys or A/D to move, space to jump)"
    elsif args.state.player.pending_challenge == :passkey
      "You bumped the passkey enemy! Use the passkey toast to continue."
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
