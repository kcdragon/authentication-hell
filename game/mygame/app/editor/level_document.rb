class LevelDocument
  GRID = 10
  MIN_ITEM_W = 60
  EDGE_GRAB = 12

  attr_reader :slug, :title, :accent, :world_w, :start_x, :time_limit, :certificate_x, :items,
              :rules

  def self.from_h(hash, rules)
    document = new(slug: hash["slug"],
                   rules: rules,
                   title: hash["title"],
                   accent: hash["accent"],
                   world_w: hash["world_w"],
                   start_x: hash["start_x"],
                   time_limit: hash["time_limit"],
                   certificate_x: hash["certificate_x"])
    (hash["platforms"] || []).each { |p| document.add_platform(p["x"], p["y"], p["w"]) }
    (hash["holes"] || []).each { |h| document.add_hole(h["x"], h["w"]) }
    (hash["enemies"] || []).each { |e| document.add_enemy(e["kind"], e["x"]) }
    document
  end

  def initialize(slug:, rules:, title: nil, accent: nil, world_w: nil, start_x: nil,
                 time_limit: nil, certificate_x: nil)
    @slug = slug
    @rules = rules
    @title = title || default_title
    @accent = accents.include?(accent) ? accent : accents.first
    @world_w = (world_w || WORLD_W).clamp(world_w_min, world_w_max)
    @start_x = start_x || JsonLevel::DEFAULT_START_X
    @time_limit = time_limit || LEVEL_TIME_LIMIT
    @certificate_x = certificate_x || default_certificate_x
    @items = []
  end

  def title=(text)
    @title = text.to_s.empty? ? default_title : text
  end

  def add_platform(x, y, w)
    item = { type: :platform, x: snap(x), y: snap(y), w: [ snap(w), MIN_ITEM_W ].max }
    clamp_into_world(item)
    @items << item
    item
  end

  def add_hole(x, w)
    item = { type: :hole, x: snap(x), w: [ snap(w), MIN_ITEM_W ].max }
    clamp_into_world(item)
    @items << item
    item
  end

  def add_enemy(kind, x)
    return nil unless enemy_kinds.include?(kind)
    item = { type: :enemy, kind: kind, x: snap(x) }
    clamp_into_world(item)
    @items << item
    item
  end

  def move_to(item, x, y)
    item[:x] = snap(x)
    item[:y] = snap(y) if item[:type] == :platform
    clamp_into_world(item)
  end

  def resize(item, w)
    return unless item[:type] == :platform || item[:type] == :hole
    item[:w] = [ snap(w), MIN_ITEM_W ].max
    clamp_into_world(item)
  end

  def delete(item)
    index = @items.index { |candidate| candidate.equal?(item) }
    @items.delete_at(index) if index
  end

  def set_start_x(x)
    @start_x = snap(x).clamp(0, @world_w - Player::WIDTH)
  end

  def set_certificate_x(x)
    @certificate_x = snap(x).clamp(0, @world_w - Certificate::SIZE)
  end

  def cycle_accent
    index = accents.index(@accent) || 0
    @accent = accents[(index + 1) % accents.length]
  end

  def adjust_world_w(delta)
    @world_w = (@world_w + delta).clamp(world_w_min, world_w_max)
    @start_x = @start_x.clamp(0, @world_w - Player::WIDTH)
    @certificate_x = @certificate_x.clamp(0, @world_w - Certificate::SIZE)
  end

  def adjust_time_limit(delta)
    @time_limit = (@time_limit + delta).clamp(rules["time_limit_min"], rules["time_limit_max"])
  end

  def item_at(wx, wy)
    @items.reverse.find { |item| inside?(rect_of(item), wx, wy) }
  end

  def platform_edge_at(wx, wy)
    @items.reverse.find do |item|
      next false unless item[:type] == :platform || item[:type] == :hole
      rect = rect_of(item)
      (wx - (rect[:x] + rect[:w])).abs <= EDGE_GRAB &&
        wy >= rect[:y] && wy <= rect[:y] + rect[:h]
    end
  end

  def start_hit?(wx, wy)
    inside?({ x: @start_x, y: GROUND_Y, w: Player::WIDTH, h: Player::HEIGHT }, wx, wy)
  end

  def certificate_hit?(wx, wy)
    inside?({ x: @certificate_x, y: GROUND_Y + Certificate::LIFT,
              w: Certificate::SIZE, h: Certificate::SIZE }, wx, wy)
  end

  def rect_of(item)
    case item[:type]
    when :platform then { x: item[:x], y: item[:y], w: item[:w], h: Platform::H }
    when :hole then { x: item[:x], y: 0, w: item[:w], h: GROUND_Y }
    when :enemy then { x: item[:x], y: GROUND_Y, w: Enemy::WIDTH, h: Enemy::HEIGHT }
    end
  end

  def to_h
    {
      "format" => rules["format"],
      "slug" => @slug,
      "title" => @title,
      "accent" => @accent,
      "world_w" => @world_w,
      "start_x" => @start_x,
      "time_limit" => @time_limit,
      "certificate_x" => @certificate_x,
      "platforms" => typed(:platform).map { |i| { "x" => i[:x], "y" => i[:y], "w" => i[:w] } },
      "holes" => typed(:hole).map { |i| { "x" => i[:x], "w" => i[:w] } },
      "enemies" => typed(:enemy).map { |i| { "kind" => i[:kind], "x" => i[:x] } }
    }
  end

  def level_data = to_h

  def to_json_string = emit(to_h)

  def world_h = rules["world_h"] || WORLD_H

  private

  def accents = rules["accents"]

  def enemy_kinds = rules["enemy_kinds"]

  def world_w_min = rules["world_w_min"]

  def world_w_max = rules["world_w_max"]

  def default_title
    return "Untitled" unless @slug
    @slug.split("-").map(&:capitalize).join(" ")
  end

  def default_certificate_x = @world_w - Level::CERTIFICATE_INSET

  def snap(value)
    (value.to_f / GRID).round * GRID
  end

  def clamp_into_world(item)
    max_x = @world_w - (item[:w] || Enemy::WIDTH)
    item[:x] = item[:x].clamp(0, [ max_x, 0 ].max)
    if item[:type] == :platform
      item[:y] = item[:y].clamp(GROUND_Y, world_h - Platform::H)
    end
  end

  def typed(type) = @items.select { |item| item[:type] == type }

  def inside?(rect, wx, wy)
    wx >= rect[:x] && wx <= rect[:x] + rect[:w] &&
      wy >= rect[:y] && wy <= rect[:y] + rect[:h]
  end

  def emit(value)
    case value
    when Hash then "{#{value.map { |k, v| "#{emit(k.to_s)}:#{emit(v)}" }.join(",")}}"
    when Array then "[#{value.map { |v| emit(v) }.join(",")}]"
    when String then "\"#{value.gsub("\\", "\\\\\\\\").gsub("\"", "\\\\\"")}\""
    when nil then "null"
    else value.to_s
    end
  end
end
