# The opening tutorial: one reachable ledge on flat ground, and a password enemy
# that only appears (marching in from the right) once the player has jumped onto
# the platform — so the lesson stays predictable: move, jump onto the platform,
# then bump the incoming enemy. Melee is off so the only way past is the password
# re-auth. Clearing it hands off to the endless main world (Main#start_main_game).
class TutorialLevel < Level
  ENEMY_SPEED = 3 # px/frame the password enemy advances leftward

  def number = 0

  def setup(args)
    # No enemy yet — update spawns it once the player reaches the platform.
    args.state.enemies = []
    # One reachable ledge near the player's start (x:200) so the jump lesson has
    # something to land on.
    args.state.platforms = [
      Platform.new(x: 360, y: Platform::TIERS.first - Platform::H, w: 180, h: Platform::H)
    ]
  end

  # Once the player has jumped onto the platform, send in the password enemy from
  # the right edge of the screen, marching left. Spawned once (guarded on the empty
  # enemy list) so a death or a hop back onto the ledge can't re-trigger it.
  def update(args)
    return unless args.state.player.reached_platform && args.state.enemies.empty?

    enemy = PasswordEnemy.new(x: args.state.camera_x + SCREEN_W)
    enemy.march_left(ENEMY_SPEED)
    args.state.enemies = [ enemy ]
  end

  def melee? = false

  # Large centered prompt, staged by progress: move, then jump onto the ledge, then
  # touch the enemy (which players would normally avoid — see the wording).
  # (Never shown while locked — tick renders the shared challenge prompt then.)
  def draw(args)
    player = args.state.player
    lines = if !player.moved
      [ "Use A/D or the arrow keys to move" ]
    elsif !player.reached_platform
      [ "Press space to jump up onto the platform" ]
    else
      [ "The * is a password enemy — normally you'd avoid enemies.",
        "Just this once, run into it to learn the re-auth challenge ->" ]
    end

    lines.each_with_index do |line, i|
      args.outputs.labels << { x: 640, y: 420 - i * 44, text: line, size_px: 32,
                               anchor_x: 0.5, anchor_y: 0.5 }
    end
  end
end
