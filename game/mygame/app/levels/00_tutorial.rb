# The opening tutorial: one reachable ledge on flat ground and a scripted pair of
# password enemies, so the lesson stays predictable — move, jump onto the platform,
# then bump the enemy marching in from the right (melee is off, so the only way past
# is the password re-auth). Clearing it drops a heal heart; grabbing it turns melee
# on and sends a second enemy in from the left for the player to defeat with the
# keyboard swing or a stomp, which finishes the tutorial and hands off to the
# password level.
#
# Sized to a single screen (world_w = SCREEN_W): the whole lesson plays in one view,
# so the player can't wander off into the empty main world and the camera never scrolls.
class TutorialLevel < Level
  ENEMY_SPEED = 3 # px/frame the password enemies advance toward the player

  def number = 0

  def world_w = SCREEN_W

  def initialize
    @healed = false
    @combat_spawned = false
    @defeated = false
  end

  def setup(args)
    # No enemy yet — update spawns it once the player reaches the platform. The
    # heal heart is dropped later, on re-auth (#on_unlock).
    args.state.enemies = []
    args.state.collectables = []
    # One reachable ledge near the player's start (x:200) so the jump lesson has
    # something to land on.
    args.state.platforms = [
      Platform.new(x: 360, y: Platform::TIERS.first - Platform::H, w: 180, h: Platform::H)
    ]
  end

  # Scripts the two enemy beats. First (guarded on the empty enemy list, so a death
  # or a hop back onto the ledge can't re-trigger it): once the player is on the
  # platform, send the password enemy in from the right edge, marching left — bump
  # it to learn the re-auth. Then, after the heal, send a second one in from the
  # left edge, marching right, for the player to defeat with the keyboard swing.
  def update(args)
    if args.state.player.reached_platform && args.state.enemies.empty? && !@combat_spawned
      enemy = PasswordEnemy.new(x: args.state.camera_x + SCREEN_W)
      enemy.march_left(ENEMY_SPEED)
      args.state.enemies = [ enemy ]
    elsif @healed && !@combat_spawned
      enemy = PasswordEnemy.new(x: args.state.camera_x - Enemy::WIDTH)
      enemy.march_right(ENEMY_SPEED, max: world_w)
      args.state.enemies = [ enemy ]
      @combat_spawned = true
    end

    # Cleared once the combat enemy is dead — but only while the player is free, so
    # a body bump (which kills the enemy but locks the player for a re-auth) doesn't
    # hand off mid-challenge. The keyboard swing kills with no lock, so it completes
    # at once.
    if @combat_spawned && args.state.enemies.none?(&:alive) &&
       !args.state.player.locked && !args.state.player.game_over
      @defeated = true
    end
  end

  # Melee is off during the re-auth lesson (so the only way past the first enemy is
  # the password challenge) and turns on once the heart is grabbed, so the keyboard
  # swing can defeat the second enemy.
  def melee? = @healed

  # Re-auth cleared: drop a heal heart on the ground a short walk ahead of the
  # player (clamped to the world so it stays reachable). Collecting it heals the
  # heart the enemy cost and triggers the keyboard-combat beat (see #update).
  def on_unlock(args)
    x = (args.state.player.x + 220).clamp(0, world_w - HeartPickup::SIZE)
    args.state.collectables << HeartPickup.new(x: x, y: GROUND_Y + HeartPickup::LIFT)
  end

  def on_collect(_args) = @healed = true

  def complete? = @defeated

  def next_level = PasswordLevel.new

  # Bold prompt, staged by progress: move, then jump onto the ledge, then touch the
  # enemy (which players would normally avoid), then heal and fight back with the
  # keyboard. Short so it reads at a glance as a closed caption at the top.
  # (Never shown while locked — tick renders the shared challenge prompt then.)
  def draw(args)
    player = args.state.player
    lines = if !player.moved
      [ "Move with A / D or arrow keys" ]
    elsif !player.reached_platform
      [ "Press Space to jump onto the ledge" ]
    elsif @healed
      [ "Fight back — left-click to swing",
        "or jump on its head to stomp it",
        "← Defeat the enemy on the left" ]
    elsif args.state.collectables.any?(&:alive)
      [ "Grab the heart to heal" ]
    else
      [ "Run into the * enemy",
        "to learn the re-auth →" ]
    end
    Caption.new(args, lines).draw
  end
end
