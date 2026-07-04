class Ui::BufferingOverlay
  def initialize(args, challenge)
    @args = args
    @challenge = challenge
  end

  def draw
    color = challenge_color

    Ui::Spinner.new(@args).draw(640, 470, color)

    @args.outputs.labels << { x: 640, y: 420, text: label,
                              size_px: 22, font: FONT_MONO_B,
                              r: color[0], g: color[1], b: color[2],
                              anchor_x: 0.5, anchor_y: 0.5 }
  end

  private

  def challenge_color
    case @challenge
    when :passkey then BLUE
    when :password then AMBER
    else PURPLE
    end
  end

  def label
    case @challenge
    when :passkey then "BUFFERING — approve the passkey toast to resume →"
    when :password then "BUFFERING — enter your password in the toast to resume →"
    else "BUFFERING — enter your TOTP code in the toast to resume →"
    end
  end
end
