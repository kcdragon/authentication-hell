SCREEN_W = 1280
SCREEN_H = 720
GROUND_Y = 100
PLAYER_W = 64
PLAYER_H = 96
MOVE_SPEED = 8

ENEMY_W = 64
ENEMY_H = 96

module Main
  def tick(args)
    args.state.player ||= { x: (SCREEN_W - PLAYER_W) / 2,
                            y: GROUND_Y,
                            w: PLAYER_W,
                            h: PLAYER_H,
                            locked: false,
                            colliding: false,
                            lock_confirmed: false,
                            pending_challenge: nil }

    # Stationary enemies parked off to each side; walk into one to collide. Each
    # carries its own auth kind (which re-auth flow it triggers) and its own
    # colliding flag so contact fires once per enemy. Right = TOTP (purple),
    # left = passkey (blue).
    args.state.enemies ||= [
      { x: SCREEN_W - ENEMY_W - 120, y: GROUND_Y, w: ENEMY_W, h: ENEMY_H,
        alive: true, colliding: false, auth: :totp, r: 90, g: 60, b: 160 },
      { x: 120, y: GROUND_Y, w: ENEMY_W, h: ENEMY_H,
        alive: true, colliding: false, auth: :passkey, r: 60, g: 120, b: 200 }
    ]

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

    # Move the player left/right with the arrow keys. No wrapping — clamp to
    # screen. Frozen while locked, until they re-authenticate.
    unless args.state.player.locked
      if args.inputs.keyboard.left
        args.state.player.x -= MOVE_SPEED
      elsif args.inputs.keyboard.right
        args.state.player.x += MOVE_SPEED
      end

      args.state.player.x = args.state.player.x.clamp(0, SCREEN_W - PLAYER_W)
    end

    # Fire once on contact (the transition, not every overlapping frame): report
    # it to that enemy's auth flow, freeze the player, and retire the enemy for good.
    args.state.enemies.each do |enemy|
      next unless enemy.alive

      colliding = args.state.player.intersect_rect?(enemy)
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

    # Enemies.
    args.state.enemies.each do |enemy|
      next unless enemy.alive

      args.outputs.solids << { x: enemy.x,
                               y: enemy.y,
                               w: enemy.w,
                               h: enemy.h,
                               r: enemy.r, g: enemy.g, b: enemy.b }
    end

    # Player.
    args.outputs.solids << { x: args.state.player.x,
                             y: args.state.player.y,
                             w: args.state.player.w,
                             h: args.state.player.h,
                             r: 200, g: 60, b: 60 }

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
      "(use the arrow keys or A/D to move)"
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
