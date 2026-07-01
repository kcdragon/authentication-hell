# The level the password level hands off to: time-based one-time passwords. On entry
# the player links a *temporary* authenticator (separate from their real 2FA) by
# scanning the QR in the toast and entering one code. Then they clear the level by
# entering three codes from three consecutive 30-second windows, "typing" each
# six-digit code on a giant number pad while a wave of enemies marches in. All the
# TOTP verification lives server-side; this level owns the keypad + the @totp state
# machine that Network::LevelTotp drives over /games/level_totp (start the QR toast,
# poll status, submit a code).
#
# The keypad is a phone number pad — 1–9 in a 3×3 grid with 0 below — of climbable
# ledges floating above the floor. Crucially, *moving over a key never enters it*: the
# player climbs the pad freely and punches in whichever key they're standing on with
# the E key, so a digit is only ever typed on purpose (collision-based entry made every
# jump a misfire). Single-screen arena (world_w = SCREEN_W) so the whole pad is in view.
class TotpLevel < Level
  attr_reader :totp, :keypad
  attr_accessor :totp_start_request, :totp_status_request,
                :totp_submit_request, :totp_next_poll

  CODE_LENGTH = 6
  REQUIRED_STREAK = 3

  WAVE_INTERVAL = 150 # ticks between enemy spawns (~2.5s)
  WAVE_CAP = 5        # most enemies alive at once
  WAVE_KINDS = [ TotpEnemy, PasswordEnemy, PasskeyEnemy ]
  ENEMY_SPEED = 3

  # Number-pad layout: rows top→bottom, then 0 on its own row below the middle column.
  # Each key is a one-way ledge a single hop above the one below; 0 is the doorstep off
  # the floor (the player starts centered right under it), and the pad climbs up from
  # there — middle column then sideways hops to the side keys.
  NUMPAD_ROWS = [ %w[7 8 9], %w[4 5 6], %w[1 2 3] ].freeze
  PAD_W = 124
  COL_X = [ 338, 578, 818 ].freeze    # three columns centered on the screen, ~116px gaps
  ROW_TOPS = [ 560, 430, 320 ].freeze # tops for 7-8-9 / 4-5-6 / 1-2-3, ~120px apart
  ZERO_TOP = 200                      # 0 sits a wide hop below the 1-2-3 row, off the floor

  def number = 2

  def title = "Time-Based One-Time Passwords"

  def accent = PURPLE

  def world_w = SCREEN_W

  def start_x = SCREEN_W / 2 - Player::WIDTH / 2

  # Linking an authenticator and entering three codes from consecutive windows takes a
  # while — give the player five minutes instead of the usual two.
  def time_limit = 300

  def setup(args)
    args.state.holes = []
    args.state.collectables = []
    args.state.enemies = []
    build_keypad(args)
    @totp = { active: true, started: false, registered: false,
              streak: 0, entered: [], pending_code: nil,
              submitting: false, complete: false, codes: nil }
    @wave_count = 0
    @last_wave_at = nil
  end

  def update(args)
    lt = @totp
    # Drain the server conversation first (registration, streak, submit results), then
    # act on this tick's input. Stops once the run is over — nothing left to unlock.
    Network::LevelTotp.new(self).poll(args.state.tick_count) unless args.state.player.game_over
    read_keypad_presses(args) if lt[:registered] && !lt[:complete]
    spawn_waves(args) if lt[:registered] && !lt[:complete]

    if lt[:complete]
      @cleared = true
      lt[:active] = false
    end
  end

  def complete? = @cleared == true

  def next_level = MainLevel.new

  # The TOTP keypad lives on the level, not args.state, so Main's generic render loop
  # can't reach it — draw it here in the camera-offset pass.
  def render_world(args, cam)
    @keypad.each { |pad| pad.render(args, cam) }
  end

  # The code-entry tray (six digit slots) and the three streak pips, under the hearts.
  def draw_hud(args)
    lt = @totp
    CODE_LENGTH.times { |slot| draw_digit_slot(args, slot, lt[:entered][slot]) }
    REQUIRED_STREAK.times { |i| draw_streak_pip(args, i, i < lt[:streak].to_i) }
    draw_dev_codes(args, lt[:codes]) if lt[:codes]
  end

  private

  def build_keypad(args)
    platforms = []
    pads = []
    NUMPAD_ROWS.each_with_index do |row, r|
      row.each_with_index { |digit, c| add_key(platforms, pads, COL_X[c], ROW_TOPS[r], digit.to_i) }
    end
    add_key(platforms, pads, COL_X[1], ZERO_TOP, 0)
    args.state.platforms = platforms
    @keypad = pads
  end

  def add_key(platforms, pads, x, top, digit)
    platforms << Platform.new(x: x, y: top - Platform::H, w: PAD_W, h: Platform::H, holds_password: false)
    pads << DigitPad.new(x: x + (PAD_W - DigitPad::SIZE) / 2, y: top, digit: digit)
  end

  # Deliberate entry: E punches in the key the player is standing on (the one their feet
  # overlap most), and nothing else does — so climbing the pad can't type a digit. When
  # the sixth lands, hand the code to Main's tick to POST and freeze entry until the
  # server answers.
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

  # The key the player is standing on: of the keys their body overlaps, the one nearest
  # their feet (rows are closer than the player is tall, so a lower key's tile reaches up
  # into the one above — feet, not the body, decide which they're on), ties going to the
  # one they're most squarely over. Nil if they're clear of every key.
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

  # A steady trickle of enemies marching in from alternating edges, capped so the floor
  # doesn't pack solid. Collisions raise the usual re-auth toasts (Main's tick handles
  # them), so the player fights/dodges while typing codes.
  def spawn_waves(args)
    @last_wave_at ||= args.state.tick_count
    return if args.state.tick_count - @last_wave_at < WAVE_INTERVAL
    return if args.state.enemies.count(&:alive) >= WAVE_CAP

    @last_wave_at = args.state.tick_count
    kind = WAVE_KINDS[@wave_count % WAVE_KINDS.length]
    if @wave_count.even?
      enemy = kind.new(x: -Enemy::WIDTH)
      enemy.march_right(ENEMY_SPEED, max: world_w)
    else
      enemy = kind.new(x: world_w)
      enemy.march_left(ENEMY_SPEED)
    end
    args.state.enemies << enemy
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

  # Dev-only: the server hands the upcoming codes over the status poll so a tester
  # without an authenticator can read them; the first is the one to enter now.
  def draw_dev_codes(args, codes)
    y = SLOT_Y - 52
    args.outputs.labels << { x: SLOT_X, y: y, text: "DEV — enter in order:", size_px: 13,
                             font: FONT_MONO_B, r: INK[0], g: INK[1], b: INK[2] }
    codes.each_with_index do |code, i|
      tone = i.zero? ? GREEN : PURPLE
      args.outputs.labels << { x: SLOT_X + i * 92, y: y - 18, text: code, size_px: 18,
                               font: FONT_MONO_B, r: tone[0], g: tone[1], b: tone[2] }
    end
  end
end
