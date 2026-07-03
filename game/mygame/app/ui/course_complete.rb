class Ui::CourseComplete
  def initialize(args)
    @args = args
  end

  def draw
    @args.outputs.solids << { x: 0, y: 0, w: SCREEN_W, h: SCREEN_H,
                              r: INDIGO[0], g: INDIGO[1], b: INDIGO[2], a: 184 }
    @args.outputs.labels << { x: 640, y: 430, text: "Course Complete",
                              size_px: 84, font: FONT_DISPLAY,
                              r: PAPER[0], g: PAPER[1], b: PAPER[2],
                              anchor_x: 0.5, anchor_y: 0.5 }
    @args.outputs.solids << { x: 640 - 210, y: 372, w: 420, h: 5,
                              r: GREEN[0], g: GREEN[1], b: GREEN[2] }
    @args.outputs.labels << { x: 640, y: 320, text: "claim your certificate from the toast →",
                              size_px: 22, font: FONT_MONO,
                              r: FAINT_INK[0], g: FAINT_INK[1], b: FAINT_INK[2],
                              anchor_x: 0.5, anchor_y: 0.5 }
  end
end
