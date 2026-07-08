class Ui::PausedOverlay
  def initialize(frame)
    @frame = frame
  end

  def draw
    @frame.outputs.sprites << { path: :solid, x: 0, y: BAR_TOP, w: SCREEN_W, h: SCREEN_H - BAR_TOP,
                              r: PAPER[0], g: PAPER[1], b: PAPER[2], a: 90 }
    cx = 640
    cy = 440
    @frame.outputs.sprites << { path: :solid, x: cx - 16, y: cy + 26, x2: cx - 16, y2: cy - 26,
                              x3: cx + 30, y3: cy,
                              r: INK[0], g: INK[1], b: INK[2] }.merge(SOLID_TRIANGLE_SOURCE)
    @frame.outputs.labels << { x: cx, y: cy - 64, text: "PAUSED",
                              size_px: 24, font: FONT_MONO_B,
                              r: INK[0], g: INK[1], b: INK[2],
                              anchor_x: 0.5, anchor_y: 0.5 }
    @frame.outputs.labels << { x: cx, y: cy - 96, text: "press play or escape to resume",
                              size_px: 16, font: FONT_MONO,
                              r: MUTED[0], g: MUTED[1], b: MUTED[2],
                              anchor_x: 0.5, anchor_y: 0.5 }

    controls = [ "A / D  or  ← →    move",
                 "Space    jump" ]
    controls.each_with_index do |line, i|
      @frame.outputs.labels << { x: cx, y: cy - 148 - i * 30, text: line,
                                size_px: 16, font: FONT_MONO,
                                r: MUTED[0], g: MUTED[1], b: MUTED[2],
                                anchor_x: 0.5, anchor_y: 0.5 }
    end
  end
end
