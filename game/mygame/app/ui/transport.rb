class Ui::Transport
  def initialize(args)
    @args = args
  end

  def draw
    bx = PLAY_BUTTON[:x]
    by = PLAY_BUTTON[:y]
    draw_play_button(bx, by) unless State.intro_active?(@args)

    limit = @args.state.level.time_limit
    elapsed = State.progress(@args) * limit
    @args.outputs.labels << { x: bx + 48, y: by + 26,
                              text: "#{timecode(elapsed)} / #{timecode(limit)}",
                              size_px: 22, font: FONT_MONO,
                              r: TS_INK[0], g: TS_INK[1], b: TS_INK[2],
                              anchor_x: 0, anchor_y: 1 }

    draw_captions(by)

    @args.outputs.labels << { x: SCREEN_W - SCRUBBER_X, y: by + 26, text: "1.0×   ⛶",
                              size_px: 20, font: FONT_MONO,
                              r: FAINT_INK[0], g: FAINT_INK[1], b: FAINT_INK[2],
                              anchor_x: 1, anchor_y: 1 }
  end

  private

  def draw_play_button(bx, by)
    @args.outputs.solids << { **PLAY_BUTTON, r: BLUE[0], g: BLUE[1], b: BLUE[2] }
    playing = @args.state.started && !@args.state.player.game_over &&
              !@args.state.player.locked && !@args.state.paused
    if playing
      @args.outputs.solids << { x: bx + 11, y: by + 9, w: 4, h: 16, r: PAPER[0], g: PAPER[1], b: PAPER[2] }
      @args.outputs.solids << { x: bx + 19, y: by + 9, w: 4, h: 16, r: PAPER[0], g: PAPER[1], b: PAPER[2] }
    else
      @args.outputs.solids << { x: bx + 12, y: by + 9, x2: bx + 12, y2: by + 25,
                                x3: bx + 26, y3: by + 17,
                                r: PAPER[0], g: PAPER[1], b: PAPER[2] }
    end
  end

  def draw_captions(by)
    cc_ink = @args.state.captions_on ? TS_INK : FAINT_INK
    @args.outputs.labels << { x: CC_BUTTON[:x], y: by + 26, text: "CC",
                              size_px: 20, font: FONT_MONO,
                              r: cc_ink[0], g: cc_ink[1], b: cc_ink[2],
                              anchor_x: 0, anchor_y: 1 }
    if @args.state.captions_on
      @args.outputs.solids << { x: CC_BUTTON[:x], y: by + 6, w: 20, h: 2,
                                r: BLUE[0], g: BLUE[1], b: BLUE[2] }
    end
  end

  def timecode(seconds)
    total = seconds.round
    format("%d:%02d", total / 60, total % 60)
  end
end
