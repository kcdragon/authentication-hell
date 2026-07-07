class Shell
  PLAY_OPTION = { x: 400, y: 330, w: 480, h: 70 }.freeze
  EDIT_OPTION = { x: 400, y: 240, w: 480, h: 70 }.freeze

  def initialize
    @mode = :loading
    @start_request = nil
    @start_data = nil
    @game = nil
    @editor = nil
  end

  def tick(args)
    @frame = Frame.new(args.inputs, args.outputs, args.state.tick_count)

    case @mode
    when :loading then loading_tick
    when :menu then menu_tick
    when :game then @game.tick(@frame)
    when :editor then @editor.tick(@frame)
    end
  end

  private

  def loading_tick
    poll_start_request
    draw_loading
  end

  def poll_start_request
    @start_request ||= DR.http_get(Network::Start.url)
    return unless @start_request[:complete]

    data = nil
    if @start_request[:http_response_code] == 200
      data = DR.parse_json(@start_request[:response_data])
    end
    @start_request = nil
    resolve_start(data || {})
  end

  def resolve_start(data)
    @start_data = data
    data["is_editor_enabled"] ? show_menu : choose_play
  end

  def show_menu
    @mode = :menu
  end

  def choose_play
    number = @start_data["start_level"] || 0
    @game = Game.new(->(game) { Level.build(number, game) })
    @mode = :game
  end

  def choose_edit
    @editor = LevelEditor.new(@start_data["editor_constants"] || {})
    @mode = :editor
  end

  def menu_tick
    keyboard = @frame.inputs.keyboard.key_down
    if keyboard.one || clicked?(PLAY_OPTION)
      choose_play
    elsif keyboard.two || clicked?(EDIT_OPTION)
      choose_edit
    else
      draw_menu
    end
  end

  def clicked?(rect)
    @frame.inputs.mouse.click && @frame.inputs.mouse.point.inside_rect?(rect)
  end

  def draw_menu
    Ui::Background.new(@frame).draw

    @frame.outputs.labels << { x: 640, y: 500, text: "AUTHENTICATION HELL",
                             size_px: 34, font: FONT_DISPLAY,
                             r: INK[0], g: INK[1], b: INK[2],
                             anchor_x: 0.5, anchor_y: 0.5 }

    draw_option(PLAY_OPTION, "1 · Play", BLUE)
    draw_option(EDIT_OPTION, "2 · Edit Levels", PURPLE)

    @frame.outputs.labels << { x: 640, y: 200, text: "development build",
                             size_px: 16, font: FONT_MONO,
                             r: MUTED[0], g: MUTED[1], b: MUTED[2],
                             anchor_x: 0.5, anchor_y: 0.5 }
  end

  def draw_option(rect, text, accent)
    @frame.outputs.solids << { x: rect[:x] - 3, y: rect[:y] - 3, w: rect[:w] + 6, h: rect[:h] + 6,
                              r: INK[0], g: INK[1], b: INK[2] }
    @frame.outputs.solids << rect.merge(r: CARD[0], g: CARD[1], b: CARD[2])
    @frame.outputs.solids << { x: rect[:x], y: rect[:y], w: 12, h: rect[:h],
                              r: accent[0], g: accent[1], b: accent[2] }
    @frame.outputs.labels << { x: rect[:x] + 36, y: rect[:y] + rect[:h] / 2, text: text,
                              size_px: 24, font: FONT_MONO_B,
                              r: INK[0], g: INK[1], b: INK[2],
                              anchor_x: 0, anchor_y: 0.5 }
  end

  def draw_loading
    ShellLoadingScene.new(@frame).draw
  end
end
