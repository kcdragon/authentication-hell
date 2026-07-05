class Ui::LevelIntro
  def initialize(frame, level)
    @frame = frame
    @level = level
  end

  def draw
    alpha = fade_alpha
    cx = 640
    cy = 392
    h = 152
    accent = @level.accent

    # 0.6 px per point of font size estimates the title width; there's no way to
    # measure a string without the engine.
    title = @level.title
    title_size = 40
    pad_x = 48
    est_w = title.length * title_size * 0.6
    w = (est_w + 2 * pad_x).clamp(520, SCREEN_W - 120).to_i
    title_size = ((w - 2 * pad_x) * title_size / est_w).to_i if est_w > w - 2 * pad_x
    left = cx - w / 2
    bottom = cy - h / 2

    @frame.outputs.solids << { x: left + 8, y: bottom - 8, w: w, h: h,
                              r: INK[0], g: INK[1], b: INK[2], a: alpha }
    @frame.outputs.solids << { x: left, y: bottom, w: w, h: h,
                              r: INK[0], g: INK[1], b: INK[2], a: alpha }
    @frame.outputs.solids << { x: left + 4, y: bottom + 4, w: w - 8, h: h - 8,
                              r: CARD[0], g: CARD[1], b: CARD[2], a: alpha }

    @frame.outputs.labels << { x: cx, y: cy + 44, text: @level.chapter_label.upcase,
                              size_px: 18, font: FONT_MONO_B,
                              r: accent[0], g: accent[1], b: accent[2], a: alpha,
                              anchor_x: 0.5, anchor_y: 0.5 }
    @frame.outputs.solids << { x: cx - 28, y: cy + 26, w: 56, h: 4,
                              r: accent[0], g: accent[1], b: accent[2], a: alpha }
    @frame.outputs.labels << { x: cx, y: cy - 18, text: title,
                              size_px: title_size, font: FONT_DISPLAY,
                              r: INK[0], g: INK[1], b: INK[2], a: alpha,
                              anchor_x: 0.5, anchor_y: 0.5 }
  end

  private

  def fade_alpha
    elapsed = @level.intro_elapsed(@frame.tick_count)
    alpha = if elapsed < LEVEL_INTRO_FADE_IN
              255 * elapsed / LEVEL_INTRO_FADE_IN
    elsif elapsed > LEVEL_INTRO_TICKS - LEVEL_INTRO_FADE_OUT
              255 * (LEVEL_INTRO_TICKS - elapsed) / LEVEL_INTRO_FADE_OUT
    else
              255
    end
    alpha.clamp(0, 255)
  end
end
