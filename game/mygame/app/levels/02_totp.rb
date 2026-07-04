class TotpLevel < Level
  attr_reader :totp, :keypad
  attr_accessor :totp_start_request, :totp_status_request,
                :totp_submit_request, :totp_next_poll

  CODE_LENGTH = 6
  REQUIRED_STREAK = 3

  WAVE_INTERVAL = 150
  WAVE_CAP = 5
  WAVE_KINDS = [ TotpEnemy, PasswordEnemy, PasskeyEnemy, BufferingEnemy ]
  ENEMY_SPEED = 3

  NUMPAD_ROWS = [ %w[7 8 9], %w[4 5 6], %w[1 2 3] ].freeze
  PAD_W = 124
  COL_X = [ 338, 578, 818 ].freeze
  # Key rows sit one hop apart (and 0 one hop off the floor) — spread them further and the pad becomes unclimbable.
  ROW_TOPS = [ 560, 430, 320 ].freeze
  ZERO_TOP = 200

  def number = 2

  def title = "Time-Based One-Time Passwords"

  def accent = PURPLE

  def world_w = SCREEN_W

  def start_x = SCREEN_W / 2 - Player::WIDTH / 2

  def time_limit = 60

  def setup(args)
    @holes = []
    @collectables = []
    @enemies = []
    build_keypad
    @totp = { active: true, started: false, registered: false,
              streak: 0, entered: [], pending_code: nil,
              submitting: false, complete: false }
    @wave_count = 0
    @last_wave_at = nil
  end

  def update(args)
    lt = @totp
    Network::LevelTotp.new(self).poll(args.state.tick_count) unless args.state.player.game_over
    read_keypad_presses(args) if lt[:registered] && !lt[:complete]
    spawn_waves(args) if lt[:registered] && !lt[:complete]

    if lt[:complete]
      @cleared = true
      lt[:active] = false
    end
  end

  def complete? = @cleared == true

  def next_level = RubyConfLevel.new

  def render_world(args, cam)
    @keypad.each { |pad| pad.render(args, cam) }
  end

  def draw_hud(args)
    lt = @totp
    CODE_LENGTH.times { |slot| draw_digit_slot(args, slot, lt[:entered][slot]) }
    REQUIRED_STREAK.times { |i| draw_streak_pip(args, i, i < lt[:streak].to_i) }
    draw_pickup_hint(args)
  end

  private

  def build_keypad
    platforms = []
    pads = []
    NUMPAD_ROWS.each_with_index do |row, r|
      row.each_with_index { |digit, c| add_key(platforms, pads, COL_X[c], ROW_TOPS[r], digit.to_i) }
    end
    add_key(platforms, pads, COL_X[1], ZERO_TOP, 0)
    @platforms = platforms
    @keypad = pads
  end

  def add_key(platforms, pads, x, top, digit)
    platforms << Platform.new(x: x, y: top - Platform::H, w: PAD_W, h: Platform::H, holds_password: false)
    pads << DigitPad.new(x: x + (PAD_W - DigitPad::SIZE) / 2, y: top, digit: digit)
  end

  def read_keypad_presses(args)
    return unless args.inputs.keyboard.key_down.e

    lt = @totp
    return if lt[:submitting] || lt[:entered].length >= CODE_LENGTH

    pad = key_under(args.state.player, @keypad)
    return unless pad

    pad.press(args.state.tick_count)
    lt[:entered] << pad.digit
    submit_code(lt) if lt[:entered].length == CODE_LENGTH
  end

  def submit_code(lt)
    lt[:pending_code] = lt[:entered].join
    lt[:entered] = []
    lt[:submitting] = true
  end

  # Key rows are closer together than the player is tall, so overlapping keys are
  # decided by the feet: nearest key vertically, ties to the squarest overlap.
  def key_under(player, keypad)
    keypad.select { |pad| overlaps?(player, pad.hitbox) }
          .min_by { |pad| [ (pad.y - player.y).abs, -overlap_width(player, pad.hitbox) ] }
  end

  def overlaps?(player, box)
    player.x < box[:x] + box[:w] && player.x + player.w > box[:x] &&
      player.y < box[:y] + box[:h] && player.y + player.h > box[:y]
  end

  def overlap_width(player, box)
    [ player.x + player.w, box[:x] + box[:w] ].min - [ player.x, box[:x] ].max
  end

  def spawn_waves(args)
    @last_wave_at ||= args.state.tick_count
    return if args.state.tick_count - @last_wave_at < WAVE_INTERVAL
    return if @enemies.count(&:alive) >= WAVE_CAP

    @last_wave_at = args.state.tick_count
    kind = WAVE_KINDS[@wave_count % WAVE_KINDS.length]
    if @wave_count.even?
      enemy = kind.new(x: -Enemy::WIDTH, level: self)
      enemy.march_right(ENEMY_SPEED, max: world_w)
    else
      enemy = kind.new(x: world_w, level: self)
      enemy.march_left(ENEMY_SPEED)
    end
    @enemies << enemy
    @wave_count += 1
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
