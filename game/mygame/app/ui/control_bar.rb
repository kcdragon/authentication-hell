class Ui::ControlBar
  def initialize(args, game)
    @args = args
    @game = game
  end

  def draw
    @args.outputs.solids << { x: 0, y: 0, w: SCREEN_W, h: BAR_TOP,
                              r: INDIGO[0], g: INDIGO[1], b: INDIGO[2] }
    @args.outputs.solids << { x: 0, y: BAR_TOP - 3, w: SCREEN_W, h: 3,
                              r: INDIGO_LIP[0], g: INDIGO_LIP[1], b: INDIGO_LIP[2] }

    draw_floor unless @game.intro_active?
    Ui::Scrubber.new(@args, @game).draw
    Ui::Transport.new(@args, @game).draw
  end

  private

  def draw_floor
    cam = @game.camera_x
    @game.level.holes.each { |hole| hole.render(@args, cam) }
    @game.level.render_floor(@args, cam)
  end
end
