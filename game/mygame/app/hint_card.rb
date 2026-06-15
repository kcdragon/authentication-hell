# The shared hint card a level draws to prompt the player. A level's #draw builds
# the current copy and shows one: it renders the neo-brutalist card (ink shadow +
# border + white face, centered mono lines), holding full opacity for a few seconds
# after the copy last changed, then fading out — so the prompt reads like a video
# caption and never permanently covers the player. The fade bookkeeping rides on
# args.state (reset on level change in Main's tick). Engine-free, so it loads under
# plain MRI like the levels and entities.
class HintCard
  HOLD_TICKS = 300 # ~5s fully visible after the copy (re)appears
  FADE_TICKS = 45  # then a short fade to nothing

  CX = 640
  CY = 560
  CARD_W = 700
  LINE_H = 40

  def initialize(args, lines)
    @args = args
    @lines = lines
  end

  # Render the copy, faded by how long it's gone unchanged. A no-op for blank copy
  # or once fully faded; the copy changing re-shows the card.
  def show
    return if @lines.nil? || @lines.empty?

    alpha = fade_alpha
    draw(alpha) if alpha.positive?
  end

  private

  # The card chrome — hard offset ink shadow, ink border, white face, centered mono
  # lines — all at the given opacity. The geometry lives here so every level's hint
  # reads alike.
  def draw(alpha)
    card_h = 56 + @lines.length * LINE_H
    left = CX - CARD_W / 2
    bottom = CY - card_h / 2
    @args.outputs.solids << { x: left + 8, y: bottom - 8, w: CARD_W, h: card_h,
                              r: INK[0], g: INK[1], b: INK[2], a: alpha }
    @args.outputs.solids << { x: left, y: bottom, w: CARD_W, h: card_h,
                              r: INK[0], g: INK[1], b: INK[2], a: alpha }
    @args.outputs.solids << { x: left + 4, y: bottom + 4, w: CARD_W - 8, h: card_h - 8,
                              r: CARD[0], g: CARD[1], b: CARD[2], a: alpha }

    top_y = CY + (@lines.length - 1) * LINE_H / 2.0
    @lines.each_with_index do |line, i|
      @args.outputs.labels << { x: CX, y: top_y - i * LINE_H, text: line, size_px: 28,
                                font: FONT_MONO_B, r: INK[0], g: INK[1], b: INK[2],
                                anchor_x: 0.5, anchor_y: 0.5, a: alpha }
    end
  end

  # Opacity (0–255) for the current copy: full while held, then a short linear fade.
  # Tracks when the copy last changed on args.state, re-showing it on a change.
  def fade_alpha
    key = @lines.join("\n")
    if @args.state.hint_key != key
      @args.state.hint_key = key
      @args.state.hint_shown_at = @args.state.tick_count
    end

    elapsed = @args.state.tick_count - @args.state.hint_shown_at
    return 0 if elapsed >= HOLD_TICKS + FADE_TICKS
    return 255 if elapsed <= HOLD_TICKS

    (255 * (1.0 - (elapsed - HOLD_TICKS).fdiv(FADE_TICKS))).to_i
  end
end
