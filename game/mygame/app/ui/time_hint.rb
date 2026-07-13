class Ui::TimeHint
  WIDTH = 560
  HEADING = "You're almost at the end of the video"
  BODY = "Defeat an enemy to rewind #{RewindFlash::LABEL}"

  def initialize(frame, game)
    @frame = frame
    @game = game
  end

  def draw
    alpha = fade_alpha
    card_h = CAPTION_PAD * 2 + 2 * CAPTION_LINE_H
    left = SCREEN_W / 2 - WIDTH / 2
    bottom = BAR_TOP + 26

    @frame.outputs.sprites << { path: :solid, x: left + 8, y: bottom - 8, w: WIDTH, h: card_h,
                              r: INK[0], g: INK[1], b: INK[2], a: alpha }
    @frame.outputs.sprites << { path: :solid, x: left, y: bottom, w: WIDTH, h: card_h,
                              r: INK[0], g: INK[1], b: INK[2], a: alpha }
    @frame.outputs.sprites << { path: :solid, x: left + 4, y: bottom + 4, w: WIDTH - 8, h: card_h - 8,
                              r: CARD[0], g: CARD[1], b: CARD[2], a: alpha }

    top_line_y = bottom + card_h - CAPTION_PAD - CAPTION_LINE_H / 2
    @frame.outputs.labels << { x: SCREEN_W / 2, y: top_line_y, text: HEADING,
                              size_px: 22, font: FONT_MONO_B,
                              r: RED[0], g: RED[1], b: RED[2], a: alpha,
                              anchor_x: 0.5, anchor_y: 0.5 }
    @frame.outputs.labels << { x: SCREEN_W / 2, y: top_line_y - CAPTION_LINE_H, text: BODY,
                              size_px: 22, font: FONT_MONO_B,
                              r: INK[0], g: INK[1], b: INK[2], a: alpha,
                              anchor_x: 0.5, anchor_y: 0.5 }
  end

  private

  def fade_alpha
    elapsed = @game.time_hint_elapsed
    alpha = if elapsed < LEVEL_INTRO_FADE_IN
              255 * elapsed / LEVEL_INTRO_FADE_IN
    elsif elapsed > TIME_HINT_TICKS - LEVEL_INTRO_FADE_OUT
              255 * (TIME_HINT_TICKS - elapsed) / LEVEL_INTRO_FADE_OUT
    else
              255
    end
    alpha.clamp(0, 255)
  end
end
