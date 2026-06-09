ME_URL = "http://localhost:3000/play/me"

SCREEN_W = 1280
SCREEN_H = 720
GROUND_Y = 100
PLAYER_W = 64
PLAYER_H = 96
MOVE_SPEED = 8

module Main
  def tick(args)
    args.state.player ||= { x: (SCREEN_W - PLAYER_W) / 2,
                            y: GROUND_Y,
                            w: PLAYER_W,
                            h: PLAYER_H }

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

    # Sky background.
    args.outputs.solids << { x: 0, y: 0, w: SCREEN_W, h: SCREEN_H, r: 135, g: 206, b: 235 }

    # Ground.
    args.outputs.solids << { x: 0, y: 0, w: SCREEN_W, h: GROUND_Y, r: 83, g: 138, b: 64 }

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
end
