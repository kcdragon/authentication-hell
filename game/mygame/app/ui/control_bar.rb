class Ui::ControlBar
  def initialize(frame, game)
    @frame = frame
    @game = game
  end

  def draw
    @frame.outputs.sprites << { path: :solid, x: 0, y: 0, w: SCREEN_W, h: BAR_TOP,
                              r: INDIGO[0], g: INDIGO[1], b: INDIGO[2] }
    @frame.outputs.sprites << { path: :solid, x: 0, y: BAR_TOP - 3, w: SCREEN_W, h: 3,
                              r: INDIGO_LIP[0], g: INDIGO_LIP[1], b: INDIGO_LIP[2] }

    draw_floor unless @game.intro_active?
    Ui::Scrubber.new(@frame, @game).draw
    Ui::Transport.new(@frame, @game).draw
  end

  private

  def draw_floor
    cam = @game.camera_x
    @game.level.holes.each { |hole| hole.render(@frame, cam) }
    @game.level.render_floor(@frame, cam)
  end
end
