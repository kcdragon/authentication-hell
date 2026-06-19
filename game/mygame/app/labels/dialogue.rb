# A start-of-level dialogue card: a neo-brutalist card (hard offset ink shadow, ink
# border, white face) centered on screen, holding one message's pre-wrapped lines in
# dark mono with a "press E to continue" footer in the level's accent. Engine-free
# (only touches args.outputs), like Caption, so it loads under plain MRI and is
# testable. Drawn while the world is frozen at a level's start, until the player E's
# through every message.
class Dialogue
  W        = 720
  PAD      = 28   # vertical padding inside the card, top and bottom
  LINE_H   = 38
  FOOTER_H = 40   # space the "press E" footer occupies below the lines
  CY       = 392  # screen y the card is centered on

  def initialize(args, lines, accent)
    @args = args
    @lines = lines
    @accent = accent
  end

  def draw
    return if @lines.nil? || @lines.empty?

    card_h = PAD * 2 + @lines.length * LINE_H + FOOTER_H
    cx = SCREEN_W / 2
    left = cx - W / 2
    bottom = CY - card_h / 2

    # Hard offset ink shadow, then the ink border, then the white face.
    @args.outputs.solids << { x: left + 8, y: bottom - 8, w: W, h: card_h,
                              r: INK[0], g: INK[1], b: INK[2] }
    @args.outputs.solids << { x: left, y: bottom, w: W, h: card_h,
                              r: INK[0], g: INK[1], b: INK[2] }
    @args.outputs.solids << { x: left + 4, y: bottom + 4, w: W - 8, h: card_h - 8,
                              r: CARD[0], g: CARD[1], b: CARD[2] }

    top_line_y = bottom + card_h - PAD - LINE_H / 2
    @lines.each_with_index do |line, i|
      @args.outputs.labels << { x: cx, y: top_line_y - i * LINE_H, text: line,
                                size_px: 24, font: FONT_MONO_B,
                                r: INK[0], g: INK[1], b: INK[2],
                                anchor_x: 0.5, anchor_y: 0.5 }
    end

    @args.outputs.labels << { x: cx, y: bottom + PAD + 4, text: "press E to continue →",
                              size_px: 18, font: FONT_MONO_B,
                              r: @accent[0], g: @accent[1], b: @accent[2],
                              anchor_x: 0.5, anchor_y: 0.5 }
  end
end
