class TotpLevel < Level
  attr_reader :totp, :keypad

  CODE_LENGTH = 6
  REQUIRED_STREAK = 3

  QR_PIECE_COUNT = 4
  GROUND_PIECE_XS = [ 600, 1120 ].freeze
  COLLECT_PLATFORMS = [ [ 300, 220 ], [ 860, 220 ] ].freeze
  COLLECT_PLATFORM_TOP = Platform::TIERS.first

  NUMPAD_ROWS = [ %w[7 8 9], %w[4 5 6], %w[1 2 3] ].freeze
  PAD_W = 124
  COL_X = [ 338, 578, 818 ].freeze
  # Key rows sit one hop apart (and 0 one hop off the floor) — spread them further and the pad becomes unclimbable.
  ROW_TOPS = [ 560, 430, 320 ].freeze
  ZERO_TOP = 200

  def number = 3

  def title = "Time-Based One-Time Passwords"

  def accent = PURPLE

  def world_w = SCREEN_W * 2

  def start_x = 80

  def time_limit = 60

  def setup(_args)
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

  def update(args)
    @totp.activate! if !@totp.started? && all_pieces_collected?
    @network.poll(args.state.tick_count) unless game.player.game_over
    read_keypad_presses(args) if @totp.registered? && !@totp.complete?
    @waves.update(args.state.tick_count, game.camera_x) unless @totp.complete?

    if @totp.complete?
      @cleared = true
      @totp.deactivate!
    end
  end

  def complete? = @cleared == true

  def next_level = RubyConfLevel.new(game)

  def render_world(args, cam)
    @keypad.each { |pad| pad.render(args, cam) }
  end

  def draw(args)
    return if @totp.registered?

    lines = if all_pieces_collected?
      [ "QR code assembled!", "scan the toast with your authenticator →" ]
    else
      [ "#{collected_pieces}/#{QR_PIECE_COUNT} QR code pieces" ]
    end
    Caption.new(args, lines, game).draw
  end

  def draw_hud(args)
    return unless @totp.registered?

    CODE_LENGTH.times { |slot| draw_digit_slot(args, slot, @totp.entered[slot]) }
    REQUIRED_STREAK.times { |i| draw_streak_pip(args, i, i < @totp.streak) }
    draw_pickup_hint(args)
  end

  private

  def all_pieces_collected? = @collectables.none? { |c| c.is_a?(QrPiece) && c.alive? }

  def collected_pieces = @collectables.count { |c| c.is_a?(QrPiece) && !c.alive? }

  def build_collection_zone
    COLLECT_PLATFORMS.each do |x, w|
      @platforms << Platform.new(x: x, y: COLLECT_PLATFORM_TOP - Platform::H, w: w, h: Platform::H,
                                 holds_password: false)
    end
    @collectables.concat(ground_pieces + platform_pieces)
  end

  def ground_pieces
    GROUND_PIECE_XS.each_with_index.map do |x, i|
      QrPiece.new(x: x, y: GROUND_Y + QrPiece::LIFT, index: i)
    end
  end

  def platform_pieces
    COLLECT_PLATFORMS.each_with_index.map do |(x, w), i|
      QrPiece.new(x: x + (w - QrPiece::SIZE) / 2, y: COLLECT_PLATFORM_TOP + QrPiece::LIFT,
                  index: GROUND_PIECE_XS.length + i)
    end
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

  def read_keypad_presses(args)
    return unless args.inputs.keyboard.key_down.e
    return if @totp.submitting? || @totp.entered.length >= CODE_LENGTH

    pad = key_under(game.player, @keypad)
    return unless pad

    pad.press(args.state.tick_count)
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

  def draw_digit_slot(args, index, digit)
    x = SLOT_X + index * SLOT_PITCH
    face = digit ? PURPLE : PAPER
    args.outputs.solids << { x: x, y: SLOT_Y, w: SLOT_W, h: SLOT_H, r: INK[0], g: INK[1], b: INK[2] }
    args.outputs.solids << { x: x + 3, y: SLOT_Y + 3, w: SLOT_W - 6, h: SLOT_H - 6,
                             r: face[0], g: face[1], b: face[2] }
    args.outputs.labels << { x: x + SLOT_W / 2, y: SLOT_Y + SLOT_H / 2 + 1, text: (digit&.to_s || "·"),
                             size_px: 20, font: FONT_MONO_B, r: PAPER[0], g: PAPER[1], b: PAPER[2],
                             anchor_x: 0.5, anchor_y: 0.5 }
  end

  PIP = 14

  def draw_streak_pip(args, index, filled)
    x = SLOT_X + index * (PIP + 8)
    y = SLOT_Y - 26
    args.outputs.solids << { x: x, y: y, w: PIP, h: PIP, r: INK[0], g: INK[1], b: INK[2] }
    face = filled ? GREEN : PAPER
    args.outputs.solids << { x: x + 2, y: y + 2, w: PIP - 4, h: PIP - 4,
                             r: face[0], g: face[1], b: face[2] }
  end

  def draw_pickup_hint(args)
    args.outputs.labels << { x: SLOT_X, y: SLOT_Y - 46, text: "press E to pick up a number",
                             size_px: 20, font: FONT_MONO,
                             r: MUTED[0], g: MUTED[1], b: MUTED[2],
                             anchor_x: 0, anchor_y: 0.5 }
  end
end
