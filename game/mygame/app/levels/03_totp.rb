class TotpLevel < Level
  attr_reader :totp, :keypad

  CODE_LENGTH = 6
  REQUIRED_STREAK = 3

  QR_PIECE_COUNT = 4
  GROUND_PIECE_XS = [ 780, 2440 ].freeze
  COLLECT_PLATFORMS = [ [ 380, 250, 220 ], [ 1150, 250, 220 ], [ 1470, 330, 220 ],
                        [ 3050, 250, 200 ], [ 3330, 330, 200 ], [ 3610, 410, 200 ] ].freeze
  PIECE_PLATFORM_INDEXES = [ 2, 5 ].freeze
  HOLE_XS = [ 2200, 2560 ].freeze
  GROUND_GUARDS = [ [ 620, PasswordEnemy ], [ 1900, BufferingEnemy ] ].freeze
  PLATFORM_GUARDS = [ [ 1, TotpEnemy ], [ 4, PasskeyEnemy ] ].freeze

  NUMPAD_ROWS = [ %w[7 8 9], %w[4 5 6], %w[1 2 3] ].freeze
  PAD_W = 124
  COL_X = [ 338, 578, 818 ].freeze
  # Key rows sit one hop apart (and 0 one hop off the floor) — spread them further and the pad becomes unclimbable.
  ROW_TOPS = [ 560, 430, 320 ].freeze
  ZERO_TOP = 200

  def number = 3

  def title = "Time-Based One-Time Passwords"

  def accent = PURPLE

  def world_w = SCREEN_W * 4

  def start_x = 80

  def time_limit = 120

  def setup(_frame)
    @holes = []
    @collectables = []
    @enemies = []
    @platforms = []
    build_collection_zone
    build_keypad
    @totp = TotpChallenge.new
    @network = Network::LevelTotp.new(@totp)
    @waves = WaveSpawner.new(self)
  end

  def update(frame)
    @totp.activate! if !@totp.started? && all_pieces_collected?
    @network.poll(frame.tick_count) unless game.player.game_over
    read_keypad_presses(frame) if @totp.registered? && !@totp.complete?
    @waves.update(frame.tick_count, game.camera_x) unless @totp.complete?

    if @totp.complete?
      @cleared = true
      @totp.deactivate!
    end
  end

  def complete? = @cleared == true

  def next_level = RubyConfLevel.new(game)

  def render_world(frame, cam, cam_y = 0)
    @keypad.each { |pad| pad.render(frame, cam, cam_y) }
  end

  def draw(frame)
    return if @totp.registered?

    lines = if all_pieces_collected?
      [ "QR code assembled!", "scan the toast with your authenticator →" ]
    else
      [ "#{collected_pieces}/#{QR_PIECE_COUNT} QR code pieces" ]
    end
    Caption.new(frame, lines, game).draw
  end

  def draw_hud(frame)
    return unless @totp.registered?

    CODE_LENGTH.times { |slot| draw_digit_slot(frame, slot, @totp.entered[slot]) }
    REQUIRED_STREAK.times { |i| draw_streak_pip(frame, i, i < @totp.streak) }
    draw_pickup_hint(frame)
  end

  private

  def all_pieces_collected? = @collectables.none? { |c| c.is_a?(QrPiece) && c.alive? }

  def collected_pieces = @collectables.count { |c| c.is_a?(QrPiece) && !c.alive? }

  def build_collection_zone
    COLLECT_PLATFORMS.each do |x, top, w|
      @platforms << Platform.new(x: x, y: top - Platform::H, w: w, h: Platform::H,
                                 holds_password: false)
    end
    @holes = HOLE_XS.map { |x| Hole.new(x: x, w: Hole::W) }
    @collectables.concat(ground_pieces + platform_pieces)
    @enemies.concat(ground_guards + platform_guards)
  end

  def ground_pieces
    GROUND_PIECE_XS.each_with_index.map do |x, i|
      QrPiece.new(x: x, y: GROUND_Y + QrPiece::LIFT, index: i)
    end
  end

  def platform_pieces
    PIECE_PLATFORM_INDEXES.each_with_index.map do |platform_index, i|
      x, top, w = COLLECT_PLATFORMS[platform_index]
      QrPiece.new(x: x + (w - QrPiece::SIZE) / 2, y: top + QrPiece::LIFT,
                  index: GROUND_PIECE_XS.length + i)
    end
  end

  def ground_guards
    GROUND_GUARDS.map { |x, kind| kind.new(x: x, level: self) }
  end

  def platform_guards
    PLATFORM_GUARDS.map { |index, kind| enemy_on(kind, @platforms[index]) }
  end

  def keypad_origin = world_w - SCREEN_W

  def build_keypad
    pads = []
    NUMPAD_ROWS.each_with_index do |row, r|
      row.each_with_index { |digit, c| add_key(@platforms, pads, keypad_origin + COL_X[c], ROW_TOPS[r], digit.to_i) }
    end
    add_key(@platforms, pads, keypad_origin + COL_X[1], ZERO_TOP, 0)
    @keypad = pads
  end

  def add_key(platforms, pads, x, top, digit)
    platforms << Platform.new(x: x, y: top - Platform::H, w: PAD_W, h: Platform::H, holds_password: false)
    pads << DigitPad.new(x: x + (PAD_W - DigitPad::SIZE) / 2, y: top, digit: digit)
  end

  def read_keypad_presses(frame)
    return unless frame.inputs.keyboard.key_down.e
    return if @totp.submitting? || @totp.entered.length >= CODE_LENGTH

    pad = key_under(game.player, @keypad)
    return unless pad

    pad.press(frame.tick_count)
    @totp.enter(pad.digit)
    @totp.submit! if @totp.entered.length == CODE_LENGTH
  end

  # Key rows are closer together than the player is tall, so overlapping keys are
  # decided by the feet: nearest key vertically, ties to the squarest overlap.
  def key_under(player, keypad)
    keypad.select { |pad| Aabb.overlap?(player, pad) }
          .min_by { |pad| [ (pad.y - player.y).abs, -Aabb.overlap_width(player, pad) ] }
  end

  SLOT_W = 30
  SLOT_H = 34
  SLOT_X = 24
  SLOT_PITCH = 36
  SLOT_Y = SCREEN_H - 114

  def draw_digit_slot(frame, index, digit)
    x = SLOT_X + index * SLOT_PITCH
    face = digit ? PURPLE : PAPER
    frame.outputs.sprites << { path: :solid, x: x, y: SLOT_Y, w: SLOT_W, h: SLOT_H, r: INK[0], g: INK[1], b: INK[2] }
    frame.outputs.sprites << { path: :solid, x: x + 3, y: SLOT_Y + 3, w: SLOT_W - 6, h: SLOT_H - 6,
                             r: face[0], g: face[1], b: face[2] }
    frame.outputs.labels << { x: x + SLOT_W / 2, y: SLOT_Y + SLOT_H / 2 + 1, text: (digit&.to_s || "·"),
                             size_px: 20, font: FONT_MONO_B, r: PAPER[0], g: PAPER[1], b: PAPER[2],
                             anchor_x: 0.5, anchor_y: 0.5 }
  end

  PIP = 14

  def draw_streak_pip(frame, index, filled)
    x = SLOT_X + index * (PIP + 8)
    y = SLOT_Y - 26
    frame.outputs.sprites << { path: :solid, x: x, y: y, w: PIP, h: PIP, r: INK[0], g: INK[1], b: INK[2] }
    face = filled ? GREEN : PAPER
    frame.outputs.sprites << { path: :solid, x: x + 2, y: y + 2, w: PIP - 4, h: PIP - 4,
                             r: face[0], g: face[1], b: face[2] }
  end

  def draw_pickup_hint(frame)
    frame.outputs.labels << { x: SLOT_X, y: SLOT_Y - 46, text: "press E to pick up a number",
                             size_px: 20, font: FONT_MONO,
                             r: MUTED[0], g: MUTED[1], b: MUTED[2],
                             anchor_x: 0, anchor_y: 0.5 }
  end
end
