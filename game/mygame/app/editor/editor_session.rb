class EditorSession
  TOOLS = [ :select, :platform, :hole, :enemy_totp, :enemy_passkey,
            :enemy_buffering, :enemy_password, :start, :certificate ].freeze

  attr_reader :document, :tool, :selection, :camera_x, :camera_y
  attr_accessor :status

  def initialize(document)
    @document = document
    @tool = TOOLS.first
    @selection = nil
    @drag = nil
    @camera_x = 0
    @camera_y = 0
    @status = nil
  end

  def select_tool(tool)
    return unless TOOLS.include?(tool)
    @tool = tool
    @selection = nil
    @drag = nil
  end

  def press(wx, wy)
    case @tool
    when :select then press_select(wx, wy)
    when :platform then place_platform(wx, wy)
    when :hole then place_hole(wx, wy)
    when :start then @document.set_start(wx - Player::WIDTH / 2, wy)
    when :certificate then @document.set_certificate_x(wx - Certificate::SIZE / 2)
    else place_enemy(wx)
    end
  end

  def drag_to(wx, wy)
    return unless @drag

    case @drag[:mode]
    when :move then @document.move_to(@drag[:item], wx - @drag[:dx], wy - @drag[:dy])
    when :size then @document.resize(@drag[:item], wx - @drag[:item][:x])
    when :move_start then @document.set_start(wx - @drag[:dx], wy - @drag[:dy])
    when :move_certificate then @document.set_certificate_x(wx - @drag[:dx])
    end
  end

  def release(_wx, _wy)
    @drag = nil
  end

  def pan(dx, dy = 0)
    x_limit = [ @document.world_w - SCREEN_W, 0 ].max
    y_limit = [ @document.world_h - SCREEN_H, 0 ].max
    @camera_x = (@camera_x + dx).clamp(0, x_limit)
    @camera_y = (@camera_y + dy).clamp(0, y_limit)
  end

  def jump_to(wx)
    limit = [ @document.world_w - SCREEN_W, 0 ].max
    @camera_x = (wx - SCREEN_W / 2).to_i.clamp(0, limit)
  end

  def delete_selection
    return unless @selection && @selection[:kind] == :item
    @document.delete(@selection[:item])
    @selection = nil
    @drag = nil
  end

  def dragging? = !@drag.nil?

  private

  def press_select(wx, wy)
    if (edged = @document.platform_edge_at(wx, wy))
      @selection = { kind: :item, item: edged }
      @drag = { mode: :size, item: edged }
    elsif (item = @document.item_at(wx, wy))
      @selection = { kind: :item, item: item }
      @drag = { mode: :move, item: item, dx: wx - item[:x], dy: wy - (item[:y] || 0) }
    elsif @document.start_hit?(wx, wy)
      @selection = { kind: :start }
      @drag = { mode: :move_start, dx: wx - @document.start_x, dy: wy - @document.start_y }
    elsif @document.certificate_hit?(wx, wy)
      @selection = { kind: :certificate }
      @drag = { mode: :move_certificate, dx: wx - @document.certificate_x }
    else
      @selection = nil
    end
  end

  def place_platform(wx, wy)
    item = @document.add_platform(wx, wy - Platform::H, LevelDocument::MIN_ITEM_W)
    @selection = { kind: :item, item: item }
    @drag = { mode: :size, item: item }
  end

  def place_hole(wx, _wy)
    item = @document.add_hole(wx, LevelDocument::MIN_ITEM_W)
    @selection = { kind: :item, item: item }
    @drag = { mode: :size, item: item }
  end

  def place_enemy(wx)
    kind = @tool.to_s.sub("enemy_", "")
    item = @document.add_enemy(kind, wx - Enemy::WIDTH / 2)
    @selection = item ? { kind: :item, item: item } : nil
  end
end
