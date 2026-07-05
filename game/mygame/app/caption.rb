class Caption
  def initialize(frame, lines, game)
    @frame = frame
    @lines = lines
    @game = game
  end

  def draw
    return unless @game.captions_on?
    return if @lines.nil? || @lines.empty?

    card_h = CAPTION_PAD * 2 + @lines.length * CAPTION_LINE_H
    left = SCREEN_W / 2 - CAPTION_W / 2
    bottom = SCREEN_H - CAPTION_MARGIN - card_h

    @frame.outputs.sprites << { path: :solid, x: left + 8, y: bottom - 8, w: CAPTION_W, h: card_h,
                              r: INK[0], g: INK[1], b: INK[2] }
    @frame.outputs.sprites << { path: :solid, x: left, y: bottom, w: CAPTION_W, h: card_h,
                              r: INK[0], g: INK[1], b: INK[2] }
    @frame.outputs.sprites << { path: :solid, x: left + 4, y: bottom + 4, w: CAPTION_W - 8, h: card_h - 8,
                              r: CARD[0], g: CARD[1], b: CARD[2] }

    top_line_y = bottom + card_h - CAPTION_PAD - CAPTION_LINE_H / 2
    @lines.each_with_index do |line, i|
      @frame.outputs.labels << { x: SCREEN_W / 2, y: top_line_y - i * CAPTION_LINE_H, text: line,
                                size_px: 22, font: FONT_MONO_B,
                                r: INK[0], g: INK[1], b: INK[2],
                                anchor_x: 0.5, anchor_y: 0.5 }
    end
  end
end
