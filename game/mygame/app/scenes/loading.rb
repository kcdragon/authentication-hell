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
    args.state.level = Level.build(args.state.start_level || 0)
    # A plain marker replaces the non-serializable response so DragonRuby's per-tick
    # state export doesn't choke on it.
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
