class Ui::Spinner
  def initialize(frame)
    @frame = frame
  end

  def draw(cx, cy, color)
    spin = (@frame.tick_count % 60) * 6
    8.times do |i|
      ang = (spin + i * 45) * Math::PI / 180
      bx = cx + Math.cos(ang) * 26
      by = cy + Math.sin(ang) * 26
      lead = i >= 6
      @frame.outputs.solids << { x: bx - 3, y: by - 3, w: 6, h: 6,
                                r: lead ? color[0] : 217, g: lead ? color[1] : 205, b: lead ? color[2] : 176 }
    end
  end
end
