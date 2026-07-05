module Ui; end

class Ui::Background
  def initialize(frame)
    @frame = frame
  end

  def draw
    @frame.outputs.background_color = PAPER
    @frame.outputs.solids << { x: 0, y: 0, w: SCREEN_W, h: SCREEN_H,
                              r: PAPER[0], g: PAPER[1], b: PAPER[2] }
  end
end
