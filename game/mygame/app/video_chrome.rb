class VideoChrome
  def initialize(args)
    @args = args
  end

  def draw_background
    args.outputs.background_color = PAPER
    args.outputs.solids << { x: 0, y: 0, w: SCREEN_W, h: SCREEN_H,
                             r: PAPER[0], g: PAPER[1], b: PAPER[2] }
  end

  def draw_bar
    args.outputs.solids << { x: 0, y: 0, w: SCREEN_W, h: BAR_TOP,
                             r: INDIGO[0], g: INDIGO[1], b: INDIGO[2] }
    args.outputs.solids << { x: 0, y: BAR_TOP - 3, w: SCREEN_W, h: 3,
                             r: INDIGO_LIP[0], g: INDIGO_LIP[1], b: INDIGO_LIP[2] }

    draw_holes unless intro_active?
    draw_scrubber
    draw_transport
  end

  def draw_spinner(cx, cy, color)
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

  def handle_caption_input
    hit = args.inputs.mouse.click && args.inputs.mouse.point.inside_rect?(CC_BUTTON)
    args.state.captions_on = !args.state.captions_on if hit
    !!hit
  end

  private

  attr_reader :args

  def draw_holes
    cam = args.state.camera_x || 0
    (args.state.holes || []).each { |hole| hole.render(args, cam) }
  end

  def draw_scrubber
    frac = progress
    track_y = SCRUBBER_Y

    args.outputs.solids << { x: SCRUBBER_X, y: track_y, w: SCRUBBER_W, h: SCRUBBER_H,
                             r: INDIGO_LIP[0], g: INDIGO_LIP[1], b: INDIGO_LIP[2] }

    buffered = (frac + 0.22).clamp(0.0, 1.0)
    args.outputs.solids << { x: SCRUBBER_X, y: track_y, w: SCRUBBER_W * buffered, h: SCRUBBER_H,
                             r: MUTED[0], g: MUTED[1], b: MUTED[2] }

    args.outputs.solids << { x: SCRUBBER_X, y: track_y, w: SCRUBBER_W * frac, h: SCRUBBER_H,
                             r: GREEN[0], g: GREEN[1], b: GREEN[2] }

    handle_color = args.state.player.game_over ? RED : CARD
    hx = SCRUBBER_X + SCRUBBER_W * frac
    args.outputs.solids << { x: hx - 8, y: track_y + SCRUBBER_H / 2 - 8, w: 16, h: 16,
                             r: INDIGO[0], g: INDIGO[1], b: INDIGO[2] }
    args.outputs.solids << { x: hx - 6, y: track_y + SCRUBBER_H / 2 - 6, w: 12, h: 12,
                             r: handle_color[0], g: handle_color[1], b: handle_color[2] }
  end

  def draw_transport
    bx = PLAY_BUTTON[:x]
    by = PLAY_BUTTON[:y]
    unless intro_active?
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

    elapsed = progress * LEVEL_TIME_LIMIT
    args.outputs.labels << { x: bx + 48, y: by + 26,
                             text: "#{timecode(elapsed)} / #{timecode(LEVEL_TIME_LIMIT)}",
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

  def timecode(seconds)
    total = seconds.round
    format("%d:%02d", total / 60, total % 60)
  end

  def progress
    started_at = args.state.level_started_at || args.state.tick_count
    ((args.state.tick_count - started_at) / (LEVEL_TIME_LIMIT * 60).to_f).clamp(0.0, 1.0)
  end

  def intro_active?
    args.state.started && args.state.level_intro_at &&
      (args.state.tick_count - args.state.level_intro_at) < LEVEL_INTRO_TICKS
  end
end
