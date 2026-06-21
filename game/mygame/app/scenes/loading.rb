class LoadingScene
  def initialize(args)
    @args = args
  end

  def tick
    poll_start_request
    Handlers.caption_input(@args)
    Ui::Background.new(@args).draw
    Ui::ControlBar.new(@args).draw
    draw_loading
  end

  private

  # Fetch the starting level once from the Rails app; the same request marks it as
  # the user's now-playing level server-side. Same-origin, so the session cookie
  # rides along and /game/start answers as the current user.
  def poll_start_request
    args = @args
    if !args.state.start_request
      args.state.start_request = DR.http_get(Network::Start.url(args))
    end

    return unless args.state.start_request[:complete]

    request = args.state.start_request
    if request[:http_response_code] == 200
      data = DR.parse_json(request[:response_data])
      args.state.start_level = data["start_level"] if data && data["start_level"]
    end
    # Resolve the starting level now that the request is done, defaulting to the
    # welcome level if it didn't answer; start_run seeds it before play begins.
    args.state.level = Level.build(args.state.start_level || 0)
    # Replace the (non-serializable) response object with a plain marker so the
    # per-tick state export doesn't choke on it and we don't re-fetch.
    args.state.start_request = :done
  end

  def draw_loading
    args = @args
    cx = 640
    cy = 392
    Ui::Spinner.new(args).draw(cx, cy, BLUE)

    args.outputs.labels << { x: cx, y: cy - 104, text: "AUTHENTICATION HELL",
                             size_px: 30, font: FONT_DISPLAY,
                             r: INK[0], g: INK[1], b: INK[2],
                             anchor_x: 0.5, anchor_y: 0.5 }
    args.outputs.labels << { x: cx, y: cy - 140, text: "loading…",
                             size_px: 18, font: FONT_MONO,
                             r: MUTED[0], g: MUTED[1], b: MUTED[2],
                             anchor_x: 0.5, anchor_y: 0.5 }
  end
end
