# The opening tutorial: a single stationary password enemy on flat ground — a
# fixed target so the lesson (move, then bump it) is predictable. Melee is off so
# the only way past is the password re-auth. Clearing it hands off to the endless
# main world (Main#start_main_game).
class TutorialLevel < Level
  def setup(args)
    enemy = Enemy.new(x: 600, auth: :password)
    enemy.vx = 0
    args.state.enemies = [ enemy ]
    args.state.platforms = []
  end

  def melee? = false

  # Large centered prompt, staged by progress: move first, then bump the enemy.
  # (Never shown while locked — tick renders the shared challenge prompt then.)
  def draw(args)
    text = if args.state.player.moved
      "Now run into the password enemy ->"
    else
      "Use A/D or the arrow keys to move"
    end

    args.outputs.labels << { x: 640, y: 400, text: text, size_px: 40,
                             anchor_x: 0.5, anchor_y: 0.5 }
  end
end
