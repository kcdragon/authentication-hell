class LevelEditor
  HUD_H = 124
  HUD_MARGIN = 24
  BUTTON_H = 34
  MINIMAP_H = 16
  PAN_SPEED = 20

  TOOL_BUTTONS = [
    [ :select, "1 SEL" ], [ :platform, "2 PLAT" ], [ :hole, "3 HOLE" ],
    [ :enemy_totp, "4 TOTP" ], [ :enemy_passkey, "5 PKEY" ], [ :enemy_buffering, "6 BUFF" ],
    [ :enemy_password, "7 PWD" ], [ :start, "8 STRT" ], [ :certificate, "9 CERT" ]
  ].freeze
  ACTION_BUTTONS = [
    [ :save, "S SAVE" ], [ :load, "L LOAD" ], [ :new, "N NEW" ],
    [ :play, "P PLAY" ], [ :promote, "O PROMO" ]
  ].freeze
  TOOL_KEYS = { one: :select, two: :platform, three: :hole,
                four: :enemy_totp, five: :enemy_passkey, six: :enemy_buffering,
                seven: :enemy_password, eight: :start, nine: :certificate }.freeze

  def initialize(rules)
    @rules = rules
    @client = Network::EditorLevels.new
    @levels = []
    @next_slug = nil
    @session = nil
    @mode = :boot
    @playtest = nil
    @status = "loading levels…"
    @title_buffer = nil
    @load_index = 0
    @world_drag = false
    @pan_grab = nil
    @awaiting = :index
    @client.fetch_index
  end

  def tick(frame)
    @frame = frame

    return playtest_tick if @playtest

    poll_network

    case @mode
    when :boot then draw_boot
    when :load_menu then load_menu_tick
    when :title_entry then title_entry_tick
    else edit_tick
    end
  end

  private

  PLAYTEST_BANNER = { x: 470, y: SCREEN_H - 34, w: 340, h: 26 }.freeze

  def playtest_tick
    if exit_playtest?
      @playtest = nil
      return
    end

    @playtest.tick(@frame)
    draw_playtest_hint
  end

  def exit_playtest?
    @frame.inputs.keyboard.key_down.tab ||
      (@frame.inputs.mouse.click && @frame.inputs.mouse.point.inside_rect?(PLAYTEST_BANNER))
  end

  def draw_playtest_hint
    @frame.outputs.sprites << PLAYTEST_BANNER.merge(path: :solid, r: INK[0], g: INK[1], b: INK[2], a: 210)
    @frame.outputs.labels << { x: 640, y: SCREEN_H - 21, text: "playtest — TAB or click here to exit",
                              size_px: 18, font: FONT_MONO,
                              r: PAPER[0], g: PAPER[1], b: PAPER[2],
                              anchor_x: 0.5, anchor_y: 0.5 }
  end

  def poll_network
    @client.update do |result|
      case @awaiting
      when :index then receive_index(result)
      when :level then receive_level(result)
      when :save then receive_save(result)
      when :promote then receive_promote(result)
      end
    end
  end

  def receive_index(result)
    return (@status = error_message(result)) unless result[:ok]

    @levels = result[:data]["levels"] || []
    @next_slug = result[:data]["next_slug"]
    if @session.nil?
      new_document
      @status = "new #{@session.document.slug}"
    end
    @mode = :edit if @mode == :boot
  end

  def receive_level(result)
    return (@status = error_message(result)) unless result[:ok]

    @session = EditorSession.new(LevelDocument.from_h(result[:data], @rules))
    @mode = :edit
    @status = "loaded #{@session.document.slug}"
  end

  def receive_save(result)
    if result[:ok]
      suffix = result[:data]["draft"] == false ? "— live in the game" : "(draft)"
      @status = "saved #{@session.document.slug} ✓ #{suffix}"
      @awaiting = :index
      @client.fetch_index
    else
      @status = error_message(result)
    end
  end

  def receive_promote(result)
    if result[:ok]
      @status = "promoted #{@session.document.slug} ✓ — now in the game"
      @awaiting = :index
      @client.fetch_index
    else
      @status = error_message(result)
    end
  end

  def error_message(result)
    case result[:code]
    when 401, 302 then "sign in first — open /auto_sign_in"
    when 404 then "not found — is this a dev server?"
    when 400, 422 then "server rejected the level data"
    else "request failed (#{result[:code]})"
    end
  end

  def new_document
    slug = @next_slug || "level-5"
    @session = EditorSession.new(LevelDocument.new(slug: slug, rules: @rules))
  end

  def edit_tick
    handle_keys
    handle_mouse
    draw_world
    draw_hud
  end

  def handle_keys
    kd = @frame.inputs.keyboard.key_down
    TOOL_KEYS.each { |key, tool| @session.select_tool(tool) if kd.send(key) }

    @session.delete_selection if kd.x || kd.delete
    @session.document.cycle_accent if kd.c
    @session.document.adjust_world_w(-320) if kd.g
    @session.document.adjust_world_w(320) if kd.h
    @session.document.adjust_time_limit(-15) if kd.j
    @session.document.adjust_time_limit(15) if kd.k

    run_action(:save) if kd.s
    run_action(:load) if kd.l
    run_action(:new) if kd.n
    run_action(:play) if kd.p
    run_action(:promote) if kd.o
    run_action(:title) if kd.t

    keyboard = @frame.inputs.keyboard
    @session.pan(-PAN_SPEED) if keyboard.left
    @session.pan(PAN_SPEED) if keyboard.right
    @session.pan(0, PAN_SPEED) if keyboard.up
    @session.pan(0, -PAN_SPEED) if keyboard.down
  end

  def run_action(action)
    case action
    when :save then save_level
    when :load then open_load_menu
    when :new then new_document
    when :play then start_playtest
    when :promote then promote_level
    when :title then begin_title_entry
    end
  end

  def save_level
    return if @client.pending?

    @awaiting = :save
    @client.save(@session.document.to_json_string)
    @status = "saving…"
  end

  def open_load_menu
    return (@status = "no saved levels yet") if @levels.empty?

    @load_index = 0
    @mode = :load_menu
  end

  def start_playtest
    document = @session.document
    @playtest = Game.new(->(game) { JsonLevel.new(game, document.level_data) })
  end

  def promote_level
    return if @client.pending?

    entry = @levels.find { |level| level["slug"] == @session.document.slug }
    return (@status = "save before promoting") unless entry
    return (@status = "#{entry["slug"]} is already in the game") unless entry["draft"]

    @awaiting = :promote
    @client.promote(entry["slug"])
    @status = "promoting…"
  end

  def begin_title_entry
    @title_buffer = ""
    @mode = :title_entry
  end

  def handle_mouse
    mouse = @frame.inputs.mouse
    @session.pan(0, (mouse.wheel.y * 60).to_i) if mouse.wheel
    handle_pan_drag(mouse)

    if mouse.click
      press(mouse)
    elsif mouse.held && @world_drag
      @session.drag_to(mouse.x + @session.camera_x, mouse.y + @session.camera_y)
    elsif mouse.up
      @session.release(mouse.x + @session.camera_x, mouse.y + @session.camera_y) if @world_drag
      @world_drag = false
    end
  end

  def handle_pan_drag(mouse)
    if mouse.button_right
      @session.pan((@pan_grab[:x] - mouse.x).to_i, (@pan_grab[:y] - mouse.y).to_i) if @pan_grab
      @pan_grab = { x: mouse.x, y: mouse.y }
    else
      @pan_grab = nil
    end
  end

  def press(mouse)
    if mouse.y >= SCREEN_H - HUD_H
      hud_press(mouse.x, mouse.y)
    else
      @world_drag = true
      @session.press(mouse.x + @session.camera_x, mouse.y + @session.camera_y)
    end
  end

  def hud_press(mx, my)
    button = buttons.find { |b| inside?(b[:rect], mx, my) }
    if button
      button[:tool] ? @session.select_tool(button[:tool]) : run_action(button[:action])
    elsif inside?(minimap_rect, mx, my)
      @session.jump_to(((mx - HUD_MARGIN) * @session.document.world_w / minimap_rect[:w].to_f).to_i)
    end
  end

  def buttons
    all = TOOL_BUTTONS.map { |tool, label| { tool: tool, label: label } } +
          ACTION_BUTTONS.map { |action, label| { action: action, label: label } }
    pitch = (SCREEN_W - 2 * HUD_MARGIN) / all.length.to_f
    all.each_with_index.map do |button, i|
      rect = { x: (HUD_MARGIN + i * pitch).to_i, y: SCREEN_H - 40,
               w: (pitch - 6).to_i, h: BUTTON_H }
      button.merge(rect: rect)
    end
  end

  def minimap_rect
    { x: HUD_MARGIN, y: SCREEN_H - 66, w: SCREEN_W - 2 * HUD_MARGIN, h: MINIMAP_H }
  end

  def inside?(rect, x, y)
    x >= rect[:x] && x <= rect[:x] + rect[:w] && y >= rect[:y] && y <= rect[:y] + rect[:h]
  end

  def draw_boot
    Ui::Background.new(@frame).draw
    @frame.outputs.labels << { x: 640, y: 380, text: "LEVEL EDITOR",
                              size_px: 30, font: FONT_DISPLAY,
                              r: INK[0], g: INK[1], b: INK[2],
                              anchor_x: 0.5, anchor_y: 0.5 }
    @frame.outputs.labels << { x: 640, y: 344, text: @status.to_s,
                              size_px: 20, font: FONT_MONO,
                              r: MUTED[0], g: MUTED[1], b: MUTED[2],
                              anchor_x: 0.5, anchor_y: 0.5 }
  end

  def draw_world
    Ui::Background.new(@frame).draw
    cam = @session.camera_x
    cam_y = @session.camera_y
    document = @session.document

    draw_grid(cam, cam_y, document)
    document.items.each { |item| draw_item(item, cam, cam_y) }
    draw_start_marker(document, cam, cam_y)
    draw_certificate(document, cam, cam_y)
    draw_selection(cam, cam_y)
  end

  def draw_grid(cam, cam_y, document)
    wx = (cam / 100 + 1).to_i * 100
    while wx < cam + SCREEN_W
      @frame.outputs.sprites << { path: :solid, x: (wx - cam).to_i, y: 0, w: 1, h: SCREEN_H,
                                r: FAINT_INK[0], g: FAINT_INK[1], b: FAINT_INK[2], a: 90 }
      wx += 100
    end

    wy = (cam_y / 100 + 1).to_i * 100
    while wy < cam_y + SCREEN_H
      @frame.outputs.sprites << { path: :solid, x: 0, y: (wy - cam_y).to_i, w: SCREEN_W, h: 1,
                                r: FAINT_INK[0], g: FAINT_INK[1], b: FAINT_INK[2], a: 60 }
      wy += 100
    end

    Platform::TIERS.each do |tier|
      @frame.outputs.sprites << { path: :solid, x: 0, y: tier - cam_y, w: SCREEN_W, h: 1,
                                r: FAINT_INK[0], g: FAINT_INK[1], b: FAINT_INK[2], a: 140 }
    end

    @frame.outputs.sprites << { path: :solid, x: 0, y: GROUND_Y - 2 - cam_y, w: SCREEN_W, h: 2,
                              r: INK[0], g: INK[1], b: INK[2] }

    [ 0, document.world_w ].each do |bound|
      next unless bound >= cam && bound <= cam + SCREEN_W
      @frame.outputs.sprites << { path: :solid, x: (bound - cam).to_i, y: 0, w: 3, h: SCREEN_H,
                                r: RED[0], g: RED[1], b: RED[2], a: 160 }
    end

    if document.world_h >= cam_y && document.world_h <= cam_y + SCREEN_H
      @frame.outputs.sprites << { path: :solid, x: 0, y: (document.world_h - cam_y).to_i - 3, w: SCREEN_W, h: 3,
                                r: RED[0], g: RED[1], b: RED[2], a: 160 }
    end
  end

  def draw_item(item, cam, cam_y)
    case item[:type]
    when :platform
      Platform.new(x: item[:x], y: item[:y], w: item[:w], h: Platform::H).render(@frame, cam, cam_y)
    when :hole
      draw_hole(item, cam, cam_y)
    when :enemy
      JsonLevel::ENEMY_KINDS[item[:kind]].new(x: item[:x], y: item[:y], level: nil).render(@frame, cam, cam_y)
    end
  end

  def draw_hole(item, cam, cam_y)
    sx = item[:x] - cam
    @frame.outputs.sprites << { path: :solid, x: sx, y: -cam_y, w: item[:w], h: GROUND_Y,
                              r: MUTED[0], g: MUTED[1], b: MUTED[2], a: 70 }
    [ sx, sx + item[:w] - 3 ].each do |ex|
      @frame.outputs.sprites << { path: :solid, x: ex, y: -cam_y, w: 3, h: GROUND_Y,
                                r: INK[0], g: INK[1], b: INK[2] }
    end
  end

  def draw_start_marker(document, cam, cam_y)
    @frame.outputs.borders << { x: document.start_x - cam, y: document.start_y - cam_y,
                               w: Player::WIDTH, h: Player::HEIGHT,
                               r: BLUE[0], g: BLUE[1], b: BLUE[2] }
    @frame.outputs.labels << { x: document.start_x - cam + Player::WIDTH / 2,
                              y: document.start_y + Player::HEIGHT + 16 - cam_y,
                              text: "START", size_px: 18, font: FONT_MONO_B,
                              r: BLUE[0], g: BLUE[1], b: BLUE[2],
                              anchor_x: 0.5, anchor_y: 0.5 }
  end

  def draw_certificate(document, cam, cam_y)
    Certificate.new(x: document.certificate_x).render(@frame, cam, cam_y)
    @frame.outputs.labels << { x: document.certificate_x - cam + Certificate::SIZE / 2,
                              y: GROUND_Y + Certificate::LIFT + Certificate::SIZE + 18 - cam_y,
                              text: "EXIT", size_px: 18, font: FONT_MONO_B,
                              r: GREEN[0], g: GREEN[1], b: GREEN[2],
                              anchor_x: 0.5, anchor_y: 0.5 }
  end

  def draw_selection(cam, cam_y)
    selection = @session.selection
    return unless selection && selection[:kind] == :item

    item = selection[:item]
    rect = @session.document.rect_of(item)
    @frame.outputs.borders << { x: rect[:x] - cam - 2, y: rect[:y] - 2 - cam_y,
                               w: rect[:w] + 4, h: rect[:h] + 4,
                               r: AMBER[0], g: AMBER[1], b: AMBER[2] }
    draw_patrol_hint(item, cam, cam_y) if item[:type] == :enemy
  end

  def draw_patrol_hint(item, cam, cam_y)
    center = item[:x] + Enemy::WIDTH / 2
    @frame.outputs.sprites << { path: :solid, x: (center - Enemy::PATROL_RANGE - cam).to_i, y: item[:y] - 8 - cam_y,
                              w: Enemy::PATROL_RANGE * 2, h: 4,
                              r: AMBER[0], g: AMBER[1], b: AMBER[2], a: 130 }
  end

  def draw_hud
    document = @session.document
    @frame.outputs.sprites << { path: :solid, x: 0, y: SCREEN_H - HUD_H, w: SCREEN_W, h: HUD_H,
                              r: INDIGO[0], g: INDIGO[1], b: INDIGO[2] }

    buttons.each { |button| draw_button(button) }
    draw_minimap(document)
    draw_meta(document)
  end

  def draw_button(button)
    rect = button[:rect]
    active = button[:tool] && button[:tool] == @session.tool
    face = active ? BLUE : INDIGO_LIP
    @frame.outputs.sprites << rect.merge(path: :solid, r: face[0], g: face[1], b: face[2])
    @frame.outputs.labels << { x: rect[:x] + rect[:w] / 2, y: rect[:y] + rect[:h] / 2,
                              text: button[:label], size_px: 20, font: FONT_MONO_B,
                              r: TS_INK[0], g: TS_INK[1], b: TS_INK[2],
                              anchor_x: 0.5, anchor_y: 0.5 }
  end

  def draw_minimap(document)
    strip = minimap_rect
    @frame.outputs.sprites << strip.merge(path: :solid, r: INK[0], g: INK[1], b: INK[2])
    scale = strip[:w] / document.world_w.to_f

    document.items.each do |item|
      color = item[:type] == :enemy ? RED : (item[:type] == :hole ? MUTED : BLUE)
      width = [ ((item[:w] || Enemy::WIDTH) * scale).to_i, 2 ].max
      @frame.outputs.sprites << { path: :solid, x: strip[:x] + (item[:x] * scale).to_i, y: strip[:y] + 3,
                                w: width, h: strip[:h] - 6,
                                r: color[0], g: color[1], b: color[2] }
    end

    @frame.outputs.borders << { x: strip[:x] + (@session.camera_x * scale).to_i, y: strip[:y],
                               w: [ (SCREEN_W * scale).to_i, 4 ].max, h: strip[:h],
                               r: PAPER[0], g: PAPER[1], b: PAPER[2] }
  end

  def draw_meta(document)
    meta = "#{document.slug} [#{document_state}] · #{document.title} · #{document.accent} · " \
           "w #{document.world_w} · #{document.time_limit}s"
    @frame.outputs.labels << { x: HUD_MARGIN, y: SCREEN_H - 86, text: meta,
                              size_px: 18, font: FONT_MONO,
                              r: TS_INK[0], g: TS_INK[1], b: TS_INK[2],
                              anchor_x: 0, anchor_y: 0.5 }
    @frame.outputs.labels << { x: SCREEN_W - HUD_MARGIN, y: SCREEN_H - 86,
                              text: @status.to_s, size_px: 18, font: FONT_MONO,
                              r: TS_INK[0], g: TS_INK[1], b: TS_INK[2],
                              anchor_x: 1, anchor_y: 0.5 }
    @frame.outputs.labels << { x: HUD_MARGIN, y: SCREEN_H - 108,
                              text: "X del · C accent · G/H width · J/K time · T title · arrows/wheel pan",
                              size_px: 18, font: FONT_MONO,
                              r: TS_INK[0], g: TS_INK[1], b: TS_INK[2], a: 180,
                              anchor_x: 0, anchor_y: 0.5 }
  end

  def document_state
    entry = @levels.find { |level| level["slug"] == @session.document.slug }
    return "unsaved" unless entry
    entry["draft"] ? "draft" : "in game"
  end

  def load_menu_tick
    kd = @frame.inputs.keyboard.key_down
    return (@mode = :edit) if kd.escape

    @load_index = (@load_index - 1) % @levels.length if kd.up
    @load_index = (@load_index + 1) % @levels.length if kd.down
    return load_selected if kd.enter

    draw_world
    draw_load_menu
    handle_load_menu_click
  end

  def load_selected
    slug = @levels[@load_index]["slug"]
    @awaiting = :level
    @client.fetch_level(slug)
    @status = "loading #{slug}…"
    @mode = :edit
  end

  def handle_load_menu_click
    mouse = @frame.inputs.mouse
    return unless mouse.click

    @levels.each_with_index do |_level, i|
      if inside?(load_row_rect(i), mouse.x, mouse.y)
        @load_index = i
        return load_selected
      end
    end
  end

  def load_row_rect(index)
    { x: 400, y: 470 - index * 44, w: 480, h: 38 }
  end

  def draw_load_menu
    @frame.outputs.sprites << { path: :solid, x: 0, y: 0, w: SCREEN_W, h: SCREEN_H,
                              r: INK[0], g: INK[1], b: INK[2], a: 140 }
    @frame.outputs.labels << { x: 640, y: 540, text: "LOAD LEVEL",
                              size_px: 26, font: FONT_DISPLAY,
                              r: PAPER[0], g: PAPER[1], b: PAPER[2],
                              anchor_x: 0.5, anchor_y: 0.5 }

    @levels.each_with_index do |level, i|
      rect = load_row_rect(i)
      face = i == @load_index ? BLUE : CARD
      @frame.outputs.sprites << rect.merge(path: :solid, r: face[0], g: face[1], b: face[2])
      ink = i == @load_index ? PAPER : INK
      @frame.outputs.labels << { x: rect[:x] + 16, y: rect[:y] + rect[:h] / 2,
                                text: "#{level['slug']} · #{level['title']}#{level['draft'] ? ' (draft)' : ''}",
                                size_px: 20, font: FONT_MONO,
                                r: ink[0], g: ink[1], b: ink[2],
                                anchor_x: 0, anchor_y: 0.5 }
    end

    @frame.outputs.labels << { x: 640, y: 470 - @levels.length * 44,
                              text: "↑/↓ · Enter loads · Esc cancels",
                              size_px: 18, font: FONT_MONO,
                              r: PAPER[0], g: PAPER[1], b: PAPER[2],
                              anchor_x: 0.5, anchor_y: 0.5 }
  end

  def title_entry_tick
    kd = @frame.inputs.keyboard.key_down
    if kd.escape
      @mode = :edit
      @title_buffer = nil
      return draw_title_entry_frame
    end
    if kd.enter
      @session.document.title = @title_buffer
      @mode = :edit
      @title_buffer = nil
      return draw_title_entry_frame
    end

    @title_buffer = @title_buffer[0...-1] if kd.backspace && !@title_buffer.empty?
    (@frame.inputs.text || []).each { |char| @title_buffer += char }

    draw_title_entry_frame
  end

  def draw_title_entry_frame
    draw_world
    draw_hud
    return unless @title_buffer

    @frame.outputs.sprites << { path: :solid, x: 340, y: 330, w: 600, h: 90,
                              r: INK[0], g: INK[1], b: INK[2], a: 220 }
    @frame.outputs.labels << { x: 640, y: 396, text: "TITLE",
                              size_px: 18, font: FONT_MONO_B,
                              r: TS_INK[0], g: TS_INK[1], b: TS_INK[2],
                              anchor_x: 0.5, anchor_y: 0.5 }
    @frame.outputs.labels << { x: 640, y: 366, text: "#{@title_buffer}_",
                              size_px: 20, font: FONT_MONO,
                              r: PAPER[0], g: PAPER[1], b: PAPER[2],
                              anchor_x: 0.5, anchor_y: 0.5 }
    @frame.outputs.labels << { x: 640, y: 340, text: "Enter commits · Esc cancels",
                              size_px: 20, font: FONT_MONO,
                              r: TS_INK[0], g: TS_INK[1], b: TS_INK[2],
                              anchor_x: 0.5, anchor_y: 0.5 }
  end
end
