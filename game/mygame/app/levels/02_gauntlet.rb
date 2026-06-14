# The finale the open world hands off to: the floor is a wall of patrolling enemies,
# so the way across is a continuous run of one-way ledges overhead — hop them from
# the start (an enemy-free patch on the left) to the far wall (an enemy-free patch on
# the right). Melee is live (inherited), so a brave player can swing through the
# floor, but with only three hearts the platforms are the safe route. Reaching the
# wall clears it and loops a fresh lap (the chain's last level can't hand off to nil
# without crashing the setup that follows).
class GauntletLevel < Level
  # Ledge path: tier-1 ledges marching right, ~190px edge-to-edge gaps (a jump
  # carries ~300px, and from one ledge the next is a flat hop), kept above the
  # enemies' reach. The first sits in the enemy-free start patch so the player can
  # climb on safely; the last reaches the enemy-free end patch to drop off.
  PLATFORM_TOP = Platform::TIERS.first
  PLATFORM_W = 170
  PLATFORM_PITCH = 360
  FIRST_PLATFORM_X = 260
  PLATFORM_COUNT = 16

  # The crawling floor: one enemy every ~350px, cycling the three auth types, walled
  # off from both the start and the end patch so the climb-on and drop-off are safe.
  ENEMY_KINDS = [ TotpEnemy, PasskeyEnemy, PasswordEnemy ]
  ENEMY_START_X = 700
  ENEMY_END_X = 5400
  ENEMY_PITCH = 350

  def number = 2

  # Pull the player back to the start (they carry the open world's right-edge x over,
  # which would otherwise read as already-finished) and lay out the hand-authored
  # scene.
  def setup(args)
    args.state.player.x = 0
    args.state.camera_x = 0
    args.state.enemies = ground_enemies
    args.state.platforms = platform_path
    args.state.collectables = []
  end

  # Latch completion at the far wall (#complete? runs without args, so it can't do the
  # check itself).
  def update(args)
    @cleared = true if reached_end?(args)
  end

  def complete? = @cleared == true

  def next_level = GauntletLevel.new

  # Brutalist card hint, matching the tutorial's prompt style.
  def draw(args)
    lines = [ "Hop the platforms —", "the floor is crawling" ]
    line_h = 40
    card_w = 560
    card_h = 56 + lines.length * line_h
    cx = 640
    cy = 560
    left = cx - card_w / 2
    bottom = cy - card_h / 2
    args.outputs.solids << { x: left + 8, y: bottom - 8, w: card_w, h: card_h,
                             r: INK[0], g: INK[1], b: INK[2] }
    args.outputs.solids << { x: left, y: bottom, w: card_w, h: card_h,
                             r: INK[0], g: INK[1], b: INK[2] }
    args.outputs.solids << { x: left + 4, y: bottom + 4, w: card_w - 8, h: card_h - 8,
                             r: CARD[0], g: CARD[1], b: CARD[2] }

    top_y = cy + (lines.length - 1) * line_h / 2.0
    lines.each_with_index do |line, i|
      args.outputs.labels << { x: cx, y: top_y - i * line_h, text: line, size_px: 28,
                               font: FONT_MONO_B, r: INK[0], g: INK[1], b: INK[2],
                               anchor_x: 0.5, anchor_y: 0.5 }
    end
  end

  private

  def platform_path
    PLATFORM_COUNT.times.map do |i|
      Platform.new(x: FIRST_PLATFORM_X + i * PLATFORM_PITCH,
                   y: PLATFORM_TOP - Platform::H, w: PLATFORM_W, h: Platform::H)
    end
  end

  def ground_enemies
    ENEMY_START_X.step(ENEMY_END_X, ENEMY_PITCH).map.with_index do |x, i|
      ENEMY_KINDS[i % ENEMY_KINDS.length].new(x: x)
    end
  end
end
