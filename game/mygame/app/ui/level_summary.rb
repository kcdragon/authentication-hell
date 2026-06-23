class Ui::LevelSummary
  def initialize(args)
    @args = args
  end

  def draw
    summary = @args.state.level_summary
    accent = @args.state.level.accent
    cx = 640
    cy = 392
    w = 520
    h = 300
    left = cx - w / 2
    bottom = cy - h / 2

    @args.outputs.solids << { x: left + 8, y: bottom - 8, w: w, h: h,
                              r: INK[0], g: INK[1], b: INK[2] }
    @args.outputs.solids << { x: left, y: bottom, w: w, h: h,
                              r: INK[0], g: INK[1], b: INK[2] }
    @args.outputs.solids << { x: left + 4, y: bottom + 4, w: w - 8, h: h - 8,
                              r: CARD[0], g: CARD[1], b: CARD[2] }

    @args.outputs.labels << { x: cx, y: cy + 122, text: "LEVEL COMPLETE",
                              size_px: 18, font: FONT_MONO_B,
                              r: accent[0], g: accent[1], b: accent[2],
                              anchor_x: 0.5, anchor_y: 0.5 }
    @args.outputs.solids << { x: cx - 28, y: cy + 104, w: 56, h: 4,
                              r: accent[0], g: accent[1], b: accent[2] }
    @args.outputs.labels << { x: cx, y: cy + 66, text: summary[:title],
                              size_px: 32, font: FONT_DISPLAY,
                              r: INK[0], g: INK[1], b: INK[2],
                              anchor_x: 0.5, anchor_y: 0.5 }

    secs = summary[:ticks].idiv(60)
    mins = secs.idiv(60)
    rem = secs % 60
    clock = "#{mins}:#{rem < 10 ? "0#{rem}" : rem}"

    @args.outputs.labels << { x: cx, y: cy + 22,
                              text: "ENEMIES  #{summary[:kills]} × #{Score::KILL_POINTS} = #{summary[:kill_points]}",
                              size_px: 18, font: FONT_MONO,
                              r: INK[0], g: INK[1], b: INK[2],
                              anchor_x: 0.5, anchor_y: 0.5 }
    @args.outputs.labels << { x: cx, y: cy - 6,
                              text: "TIME  #{clock}  BONUS +#{summary[:time_bonus]}",
                              size_px: 18, font: FONT_MONO,
                              r: INK[0], g: INK[1], b: INK[2],
                              anchor_x: 0.5, anchor_y: 0.5 }
    @args.outputs.labels << { x: cx, y: cy - 34,
                              text: "HEARTS  #{summary[:hearts]} × #{Score::HEART_BONUS} = #{summary[:heart_bonus]}",
                              size_px: 18, font: FONT_MONO,
                              r: INK[0], g: INK[1], b: INK[2],
                              anchor_x: 0.5, anchor_y: 0.5 }

    @args.outputs.labels << { x: cx, y: cy - 80, text: "SCORE  #{summary[:total]}",
                              size_px: 44, font: FONT_DISPLAY,
                              r: GREEN[0], g: GREEN[1], b: GREEN[2],
                              anchor_x: 0.5, anchor_y: 0.5 }
    @args.outputs.labels << { x: cx, y: cy - 118, text: "press space or E to continue",
                              size_px: 16, font: FONT_MONO,
                              r: MUTED[0], g: MUTED[1], b: MUTED[2],
                              anchor_x: 0.5, anchor_y: 0.5 }
  end
end
