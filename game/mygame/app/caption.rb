# The closed captions: the prompt a level passes in, drawn as a neo-brutalist card
# (hard offset ink shadow, ink border, white face, dark mono text) at the top of the
# screen. Shown only while CC is toggled on (args.state.captions_on) and persistent
# while it is — the CC toggle is the only thing that shows or hides it. Engine-free
# (only touches args.outputs / args.state), so it loads under plain MRI like the levels.
class Caption
  def initialize(args, lines)
    @args = args
    @lines = lines
  end

  # Draw the caption box and its lines — a no-op when CC is off or there's no copy.
  def draw
    return unless @args.state.captions_on
    return if @lines.nil? || @lines.empty?

    card_h = CAPTION_PAD * 2 + @lines.length * CAPTION_LINE_H
    left = SCREEN_W / 2 - CAPTION_W / 2
    bottom = SCREEN_H - CAPTION_MARGIN - card_h

    # Hard offset ink shadow, then the ink border, then the white face.
    @args.outputs.solids << { x: left + 8, y: bottom - 8, w: CAPTION_W, h: card_h,
                              r: INK[0], g: INK[1], b: INK[2] }
    @args.outputs.solids << { x: left, y: bottom, w: CAPTION_W, h: card_h,
                              r: INK[0], g: INK[1], b: INK[2] }
    @args.outputs.solids << { x: left + 4, y: bottom + 4, w: CAPTION_W - 8, h: card_h - 8,
                              r: CARD[0], g: CARD[1], b: CARD[2] }

    top_line_y = bottom + card_h - CAPTION_PAD - CAPTION_LINE_H / 2
    @lines.each_with_index do |line, i|
      @args.outputs.labels << { x: SCREEN_W / 2, y: top_line_y - i * CAPTION_LINE_H, text: line,
                                size_px: 22, font: FONT_MONO_B,
                                r: INK[0], g: INK[1], b: INK[2],
                                anchor_x: 0.5, anchor_y: 0.5 }
    end
  end
end
