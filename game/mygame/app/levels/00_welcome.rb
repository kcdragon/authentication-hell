# The opening welcome level: one reachable ledge on flat ground and a scripted pair of
# password enemies, so the lesson stays predictable — move, jump onto the platform,
# then bump the enemy marching in from the right (a TutorialEnemy — it can't be
# stomped, so the only way past is the password re-auth). Clearing it drops a heal
# heart; grabbing it sends a second, ordinary enemy in from the left for the player to
# defeat with a stomp, which drops the completion certificate; grabbing it finishes the
# welcome level and hands off to the password level.
#
# Sized to a single screen (world_w = SCREEN_W): the whole lesson plays in one view,
# so the player can't wander off into the empty main world and the camera never scrolls.
class WelcomeLevel < Level
  ENEMY_SPEED = 3 # px/frame the password enemies advance toward the player

  def number = 0

  def title = "Welcome"

  def world_w = SCREEN_W

  # Single-screen lesson: start mid-left so the ledge (x:360) is a short hop ahead.
  def start_x = 200

  def initialize
    super
    @combat_spawned = false
    @certificate_dropped = false
  end

  def setup(_args)
    # No enemy yet — update spawns it once the player reaches the platform. The
    # heal heart is dropped later, on re-auth (#on_unlock).
    @enemies = []
    @collectables = []
    @holes = [] # flat ground — the lesson stays predictable
    # One reachable ledge near the player's start (x:200) so the jump lesson has
    # something to land on.
    @platforms = [
      Platform.new(x: 360, y: Platform::TIERS.first - Platform::H, w: 180, h: Platform::H)
    ]
  end

  # Scripts the two enemy beats. First (guarded on the empty enemy list, so a death
  # or a hop back onto the ledge can't re-trigger it): once the player is on the
  # platform, send the password enemy in from the right edge, marching left — bump
  # it to learn the re-auth. Then, after the heal, send a second one in from the
  # left edge, marching right, for the player to defeat with a stomp.
  def update(args)
    if args.state.player.reached_platform && @enemies.empty? && !@combat_spawned
      enemy = TutorialEnemy.new(x: args.state.camera_x + SCREEN_W)
      enemy.march_left(ENEMY_SPEED)
      @enemies = [ enemy ]
    elsif healed? && !@combat_spawned
      enemy = PasswordEnemy.new(x: args.state.camera_x - Enemy::WIDTH)
      enemy.march_right(ENEMY_SPEED, max: world_w)
      @enemies = [ enemy ]
      @combat_spawned = true
    end

    # Combat enemy dead and the player is free (a body bump kills it but locks the
    # player for a re-auth — wait until that clears, not mid-challenge): drop the
    # completion certificate a short walk ahead, once. Grabbing it finishes the lesson.
    if @combat_spawned && @enemies.none?(&:alive) &&
       !args.state.player.locked && !args.state.player.game_over && !@certificate_dropped
      x = (args.state.player.x + 180).clamp(0, world_w - Certificate::SIZE)
      @collectables << Certificate.new(x: x)
      @certificate_dropped = true
    end

    @cleared = true if certificate_collected?(args)
  end

  # Re-auth cleared: drop a heal heart on the ground a short walk ahead of the
  # player (clamped to the world so it stays reachable). Collecting it heals the
  # heart the enemy cost and triggers the stomp-combat beat (see #update).
  def on_unlock(args)
    x = (args.state.player.x + 220).clamp(0, world_w - HeartPickup::SIZE)
    @collectables << HeartPickup.new(x: x, y: GROUND_Y + HeartPickup::LIFT)
  end

  def complete? = @cleared == true

  def next_level = PasswordLevel.new

  # Ticks to wait after a beat's milestone is reached before its card freezes the
  # world. Without it, dismissing one hint and immediately hitting the next milestone
  # pops the following card in the same instant, which reads as jarring.
  DIALOGUE_DELAY = 36

  # The welcome level's coaching, staged: each beat pairs a hint with the milestone that
  # surfaces it. Main freezes the world on the pending beat until the player presses
  # E, then plays on until the next milestone — so a hint only appears the moment it's
  # relevant (move, then jump, bump the enemy, heal, fight back, finish).
  def dialogue(args) = beats(args).map { |_ready, lines| lines }

  # The hints surface mid-play, so the frozen scene stays visible behind the card
  # (hiding it would read as the level vanishing each time a hint pops).
  def dialogue_hides_scene? = false

  # A beat surfaces a short delay after its milestone is met: stamp the tick the
  # pending beat first becomes eligible, then hold its card back until DIALOGUE_DELAY
  # passes. The opening card is exempt — it follows the intro fade, not a dismissal.
  def dialogue_ready?(args)
    i = @dialogue_index.to_i
    return false unless beats(args)[i]&.first == true
    return true if i.zero?

    (@beat_ready_at ||= {})[i] ||= args.state.tick_count
    args.state.tick_count - @beat_ready_at[i] >= DIALOGUE_DELAY
  end

  private

  def healed? = @collectables.any? { |c| c.is_a?(HeartPickup) && !c.alive? }

  def beats(args)
    player = args.state.player
    [
      [ true,                                          [ "Move with A / D or arrow keys" ] ],
      [ player.moved,                                  [ "Press Space to jump onto the ledge" ] ],
      [ player.reached_platform,                       [ "Run into the enemy",
                                                         "to learn the re-auth →" ] ],
      [ @collectables.any?(&:alive?),                  [ "Grab the heart to heal" ] ],
      [ healed?,                                       [ "Fight back — jump on its head",
                                                         "to stomp it",
                                                         "← Defeat the enemy on the left" ] ],
      [ @certificate_dropped,                          [ "Grab your certificate",
                                                         "to finish →" ] ]
    ]
  end
end
