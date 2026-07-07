class ShellLoadingScene
  def initialize(frame)
    @frame = frame
  end

  def draw
    Ui::Background.new(@frame).draw
    draw_loading
  end

  private

  def draw_loading
    cx = 640
    cy = 392
    Ui::Spinner.new(@frame).draw(cx, cy, BLUE)

    @frame.outputs.labels << { x: cx, y: cy - 104, text: "AUTHENTICATION HELL",
                             size_px: 30, font: FONT_DISPLAY,
                             r: INK[0], g: INK[1], b: INK[2],
                             anchor_x: 0.5, anchor_y: 0.5 }
    @frame.outputs.labels << { x: cx, y: cy - 140, text: "loading…",
                             size_px: 18, font: FONT_MONO,
                             r: MUTED[0], g: MUTED[1], b: MUTED[2],
                             anchor_x: 0.5, anchor_y: 0.5 }
  end
end
