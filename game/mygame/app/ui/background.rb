module Ui; end

class Ui::Background
  def initialize(args)
    @args = args
  end

  def draw
    @args.outputs.background_color = PAPER
    @args.outputs.solids << { x: 0, y: 0, w: SCREEN_W, h: SCREEN_H,
                              r: PAPER[0], g: PAPER[1], b: PAPER[2] }
  end
end
