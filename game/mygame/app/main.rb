ME_URL = "http://localhost:3000/play/me"
COLLISION_URL = "http://localhost:3000/play/collision"

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
                            h: PLAYER_H }

    # A stationary enemy parked off to the right. Walk into it to collide.
    args.state.enemy ||= { x: SCREEN_W - ENEMY_W - 120,
                           y: GROUND_Y,
                           w: ENEMY_W,
                           h: ENEMY_H }

    # Fetch the logged-in user's name once from the Rails app. Same-origin, so the
    # session cookie rides along and /play/me answers as the current user.
    args.state.username ||= 'there'
    if !args.state.name_request
      args.state.name_request = DR.http_get(ME_URL)
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

    # Move the player left/right with the arrow keys. No wrapping — clamp to screen.
    if args.inputs.keyboard.left
      args.state.player.x -= MOVE_SPEED
    elsif args.inputs.keyboard.right
      args.state.player.x += MOVE_SPEED
    end

    args.state.player.x = args.state.player.x.clamp(0, SCREEN_W - PLAYER_W)

    # Tell the Rails app about a collision, but only on the transition into
    # contact (not every frame we overlap) so it broadcasts one message per hit.
    colliding = args.state.player.intersect_rect?(args.state.enemy)
    if colliding && !args.state.colliding
      report_collision(args)
    end
    args.state.colliding = colliding

    # Drop the (non-serializable) response handle once the POST finishes so the
    # per-tick state export doesn't choke on it; a fresh hit starts a new one.
    if args.state.collision_request &&
       args.state.collision_request != :pending &&
       args.state.collision_request[:complete]
      args.state.collision_request = nil
    end

    # Sky background.
    args.outputs.solids << { x: 0, y: 0, w: SCREEN_W, h: SCREEN_H, r: 135, g: 206, b: 235 }

    # Ground.
    args.outputs.solids << { x: 0, y: 0, w: SCREEN_W, h: GROUND_Y, r: 83, g: 138, b: 64 }

    # Enemy.
    args.outputs.solids << { x: args.state.enemy.x,
                             y: args.state.enemy.y,
                             w: args.state.enemy.w,
                             h: args.state.enemy.h,
                             r: 90, g: 60, b: 160 }

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

    args.outputs.labels << { x: 640,
                             y: 640,
                             text: "(use the arrow keys or A/D to move)",
                             size_px: 20,
                             anchor_x: 0.5,
                             anchor_y: 0.5 }
  end

  # POST to the Rails app so it can broadcast a message to the page. Same-origin,
  # so the session cookie identifies the player; the body is empty but the API
  # wants form-encoded content.
  def report_collision(args)
    args.state.collision_request = :pending
    args.state.collision_request = DR.http_post(
      COLLISION_URL,
      {},
      [ "Content-Type: application/x-www-form-urlencoded" ]
    )
  end
end
