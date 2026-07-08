class JsonLevel < Level
  NUMBER = 99

  ENEMY_KINDS = {
    "totp" => TotpEnemy,
    "passkey" => PasskeyEnemy,
    "buffering" => BufferingEnemy,
    "password" => PasswordEnemy,
    "tutorial" => TutorialEnemy
  }.freeze

  ACCENTS = {
    "blue" => BLUE,
    "green" => GREEN,
    "red" => RED,
    "purple" => PURPLE,
    "amber" => AMBER,
    "teal" => TEAL,
    "ruby" => RUBY
  }.freeze

  DEFAULT_START_X = 200

  def initialize(game, data)
    super(game)
    @data = data
  end

  def number = NUMBER

  def title = @data["title"] || default_title

  def chapter_label = "Draft"

  def accent = ACCENTS[@data["accent"]] || BLUE

  def world_w = @data["world_w"] || WORLD_W

  def start_x = @data["start_x"] || DEFAULT_START_X

  def start_y = @data["start_y"] || GROUND_Y

  def time_limit = @data["time_limit"] || LEVEL_TIME_LIMIT

  def setup(_frame)
    @platforms = (@data["platforms"] || []).map do |p|
      Platform.new(x: p["x"], y: p["y"], w: p["w"], h: Platform::H)
    end
    @holes = (@data["holes"] || []).map { |h| Hole.new(x: h["x"], w: h["w"]) }
    @enemies = (@data["enemies"] || []).map { |e| build_enemy(e) }.compact
    @collectables = [ Certificate.new(x: certificate_x) ]
  end

  def complete? = @collectables.any? { |c| c.is_a?(Certificate) && !c.alive? }

  def next_level = nil

  private

  def build_enemy(entry)
    klass = ENEMY_KINDS[entry["kind"]]
    klass&.new(x: entry["x"], level: self)
  end

  def certificate_x = @data["certificate_x"] || world_w - CERTIFICATE_INSET

  def default_title
    slug = @data["slug"]
    return "Untitled" unless slug
    slug.split("-").map(&:capitalize).join(" ")
  end
end
