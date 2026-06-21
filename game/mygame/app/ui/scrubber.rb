class Ui::Scrubber
  def initialize(args)
    @args = args
  end

  def draw
    frac = State.progress(@args)
    track_y = SCRUBBER_Y

    @args.outputs.solids << { x: SCRUBBER_X, y: track_y, w: SCRUBBER_W, h: SCRUBBER_H,
                              r: INDIGO_LIP[0], g: INDIGO_LIP[1], b: INDIGO_LIP[2] }

    buffered = (frac + 0.22).clamp(0.0, 1.0)
    @args.outputs.solids << { x: SCRUBBER_X, y: track_y, w: SCRUBBER_W * buffered, h: SCRUBBER_H,
                              r: MUTED[0], g: MUTED[1], b: MUTED[2] }

    @args.outputs.solids << { x: SCRUBBER_X, y: track_y, w: SCRUBBER_W * frac, h: SCRUBBER_H,
                              r: GREEN[0], g: GREEN[1], b: GREEN[2] }

    handle_color = @args.state.player.game_over ? RED : CARD
    hx = SCRUBBER_X + SCRUBBER_W * frac
    @args.outputs.solids << { x: hx - 8, y: track_y + SCRUBBER_H / 2 - 8, w: 16, h: 16,
                              r: INDIGO[0], g: INDIGO[1], b: INDIGO[2] }
    @args.outputs.solids << { x: hx - 6, y: track_y + SCRUBBER_H / 2 - 6, w: 12, h: 12,
                              r: handle_color[0], g: handle_color[1], b: handle_color[2] }
  end
end
