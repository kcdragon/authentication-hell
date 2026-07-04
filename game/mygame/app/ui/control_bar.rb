class Ui::ControlBar
  def initialize(args)
    @args = args
  end

  def draw
    @args.outputs.solids << { x: 0, y: 0, w: SCREEN_W, h: BAR_TOP,
                              r: INDIGO[0], g: INDIGO[1], b: INDIGO[2] }
    @args.outputs.solids << { x: 0, y: BAR_TOP - 3, w: SCREEN_W, h: 3,
                              r: INDIGO_LIP[0], g: INDIGO_LIP[1], b: INDIGO_LIP[2] }

    draw_floor unless State.intro_active?(@args)
    Ui::Scrubber.new(@args).draw
    Ui::Transport.new(@args).draw
  end

  private

  def draw_floor
    cam = @args.state.camera_x || 0
    @args.state.level.holes.each { |hole| hole.render(@args, cam) }
    @args.state.level.render_floor(@args, cam)
  end
end
