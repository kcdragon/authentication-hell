class Editor::LevelFile
  class CorruptFile < StandardError; end

  SLUG_FORMAT = /\A[a-z0-9][a-z0-9\-]{0,40}\z/
  FORMAT = 1
  ENEMY_KINDS = %w[ totp passkey buffering password tutorial ].freeze
  ACCENTS = %w[ blue green red purple amber teal ruby ].freeze
  WORLD_W_RANGE = (1280..12_800)
  TIME_LIMIT_RANGE = (10..600)
  GROUND_Y = 100
  WORLD_H = 2160
  PLATFORM_H = 30
  PLATFORM_Y_RANGE = (GROUND_Y..WORLD_H - PLATFORM_H)
  START_Y_RANGE = (GROUND_Y..WORLD_H)
  FIRST_NUMBER = 5

  cattr_accessor :root, default: Rails.root.join("game/mygame/data/levels")
  cattr_accessor :draft_root, default: Rails.root.join("level_drafts")

  attr_reader :data, :errors

  def self.all
    published = load_dir(root, draft: false)
    taken = published.map(&:slug)
    drafts = load_dir(draft_root, draft: true).reject { |level| taken.include?(level.slug) }
    (published + drafts).sort_by(&:slug)
  end

  def self.load_dir(dir, draft:)
    Dir.glob(dir.join("*.json").to_s).sort.map do |path|
      new(parse(path), draft: draft)
    end
  end
  private_class_method :load_dir

  def self.parse(path)
    parsed = JSON.parse(File.read(path))
    raise CorruptFile, "#{path} does not contain a JSON object" unless parsed.is_a?(Hash)
    parsed
  rescue JSON::ParserError => error
    raise CorruptFile, "#{path} is not valid JSON: #{error.message}"
  end
  private_class_method :parse

  def self.find(slug)
    return nil unless slug.to_s.match?(SLUG_FORMAT)

    [ [ root, false ], [ draft_root, true ] ].each do |dir, draft|
      path = dir.join("#{slug}.json")
      return new(parse(path), draft: draft) if File.file?(path)
    end
    nil
  end

  def self.next_slug
    pattern = "level-*.json"
    paths = Dir.glob(root.join(pattern).to_s) + Dir.glob(draft_root.join(pattern).to_s)
    numbers = paths.map { |path| File.basename(path)[/level-(\d+)\.json\z/, 1].to_i }
    "level-#{[ numbers.max.to_i + 1, FIRST_NUMBER ].max}"
  end

  def self.client_constants
    {
      format: FORMAT,
      enemy_kinds: ENEMY_KINDS,
      accents: ACCENTS,
      world_w_min: WORLD_W_RANGE.min,
      world_w_max: WORLD_W_RANGE.max,
      world_h: WORLD_H,
      time_limit_min: TIME_LIMIT_RANGE.min,
      time_limit_max: TIME_LIMIT_RANGE.max
    }
  end

  def initialize(data, draft: nil)
    @data = data.is_a?(Hash) ? data : {}
    @errors = []
    @draft = draft.nil? ? !published? : draft
  end

  def draft? = @draft

  def slug = data["slug"]

  def title = data["title"]

  def valid?
    @errors = []
    validate_meta
    validate_geometry if @errors.empty?
    @errors.empty?
  end

  def write
    raise ArgumentError, errors.join(", ") unless valid?

    dir = draft? ? draft_root : root
    FileUtils.mkdir_p(dir)
    File.write(safe_path(dir), JSON.pretty_generate(normalized) + "\n")
  end

  def promote!
    raise ArgumentError, "already in the game" unless draft?

    FileUtils.mkdir_p(root)
    FileUtils.mv(safe_path(draft_root), safe_path(root))
    @draft = false
  end

  private

  def published?
    slug.to_s.match?(SLUG_FORMAT) && File.file?(root.join("#{slug}.json"))
  end

  def safe_path(dir)
    path = File.expand_path(dir.join("#{slug}.json"))
    raise ArgumentError, "slug escapes the levels directory" unless
      path.start_with?(File.expand_path(dir) + File::SEPARATOR)
    path
  end

  def normalized
    {
      "format" => 1,
      "slug" => slug,
      "title" => title.to_s,
      "accent" => data["accent"],
      "world_w" => data["world_w"],
      "start_x" => data["start_x"],
      "start_y" => data["start_y"] || GROUND_Y,
      "time_limit" => data["time_limit"],
      "certificate_x" => data["certificate_x"],
      "platforms" => data["platforms"].map { |p| p.slice("x", "y", "w") },
      "holes" => data["holes"].map { |h| h.slice("x", "w") },
      "enemies" => data["enemies"].map { |e| e.slice("kind", "x") }
    }
  end

  def validate_meta
    errors << "format must be #{FORMAT}" unless data["format"] == FORMAT
    errors << "slug is invalid" unless slug.to_s.match?(SLUG_FORMAT)
    errors << "accent is unknown" unless ACCENTS.include?(data["accent"])
    errors << "world_w out of range" unless WORLD_W_RANGE.cover?(data["world_w"])
    errors << "time_limit out of range" unless TIME_LIMIT_RANGE.cover?(data["time_limit"])
    validate_marker "start_x"
    validate_marker "certificate_x"
    validate_start_y
  end

  def validate_marker(key)
    value = data[key]
    in_world = value.is_a?(Integer) && value >= 0 && value <= data["world_w"].to_i
    errors << "#{key} out of range" unless in_world
  end

  def validate_start_y
    value = data.fetch("start_y", GROUND_Y)
    errors << "start_y out of range" unless value.is_a?(Integer) && START_Y_RANGE.cover?(value)
  end

  def validate_geometry
    if entries_valid?("platforms", %w[ x y w ])
      errors << "platform y out of range" unless
        data["platforms"].all? { |p| PLATFORM_Y_RANGE.cover?(p["y"]) }
    else
      errors << "platforms are malformed"
    end
    errors << "holes are malformed" unless entries_valid?("holes", %w[ x w ])
    errors << "enemies are malformed" unless enemies_valid?
  end

  def entries_valid?(key, required)
    entries = data[key]
    entries.is_a?(Array) && entries.all? do |entry|
      entry.is_a?(Hash) && required.all? { |attr| entry[attr].is_a?(Integer) }
    end
  end

  def enemies_valid?
    entries_valid?("enemies", %w[ x ]) &&
      data["enemies"].all? { |e| ENEMY_KINDS.include?(e["kind"]) }
  end
end
