class ApiKeyLevel < Level
  CHASM_X = 3400
  CHASM_W = 640
  BRIDGE_OVERHANG = 40
  PLATFORM_MARGIN = 60

  PIT_XS = [ 1100, 2300 ].freeze
  FAR_ENEMY_XS = [ 4500, 5300 ].freeze

  HAZARD_KINDS = [ TotpEnemy, PasskeyEnemy, BufferingEnemy ]
  HAZARD_PITCH = 1100

  attr_reader :bridge

  def number = 2

  def title = "API Keys"

  def accent = TEAL

  def time_limit = 300

  def dialogue(_frame)
    [
      [ "The chasm ahead is too wide to jump —",
        "its bridge only extends for authenticated requests" ],
      [ "Mint an API key, then call the bridge API",
        "from a real terminal to extend it" ]
    ]
  end

  def setup(_frame)
    @bridge = Bridge.new(x: CHASM_X - BRIDGE_OVERHANG, span: CHASM_W + 2 * BRIDGE_OVERHANG)
    @holes = PIT_XS.map { |x| Hole.new(x: x, w: Hole::W) } + [ Hole.new(x: CHASM_X, w: CHASM_W) ]
    @platforms = scattered_platforms << @bridge
    @collectables = [ certificate_at_exit ]
    @enemies = near_enemies(game.player.x) + far_enemies
    @network = Network::LevelApiKey.new(self)
  end

  def update(frame)
    @network.poll(frame.tick_count) unless game.player.game_over
    @bridge.update
    @cleared = true if certificate_collected?(frame)
  end

  def open_bridge!
    @bridge.open!
  end

  def complete? = @cleared == true

  def next_level = TotpLevel.new(game)

  def render_floor(frame, cam, cam_y = 0)
    @bridge&.render(frame, cam, cam_y)
  end

  def draw(frame)
    lines = if @bridge.extended?
      [ "Bridge extended —", "cross and finish →" ]
    else
      [ "Bridge retracted — authenticate", "via the API to extend it" ]
    end
    Caption.new(frame, lines, game).draw
  end

  private

  def scattered_platforms
    Platform.scatter.reject do |platform|
      platform.x + platform.w > CHASM_X - PLATFORM_MARGIN &&
        platform.x < CHASM_X + CHASM_W + PLATFORM_MARGIN
    end
  end

  def near_enemies(player_x)
    start = player_x + Enemy::SAFE_GAP
    count = ((CHASM_X - 200 - start) / HAZARD_PITCH).to_i + 1
    count.times.map do |i|
      HAZARD_KINDS[i % HAZARD_KINDS.length].new(x: start + i * HAZARD_PITCH, level: self)
    end
  end

  def far_enemies
    FAR_ENEMY_XS.map.with_index do |x, i|
      HAZARD_KINDS[i % HAZARD_KINDS.length].new(x: x, level: self)
    end
  end
end
