# The endless main world the tutorial hands off to. Its scene (random enemies +
# platforms) is seeded inline by Main#start_main_game; this class just carries the
# level-level behavior — melee is live (inherited), with a controls reminder.
class MainLevel < Level
  # The unlocked controls reminder, shown while the player is free to roam.
  def draw(args)
    args.outputs.labels << { x: 640, y: 640,
                             text: "(arrow keys or A/D to move, space to jump, click to swing)",
                             size_px: 20, anchor_x: 0.5, anchor_y: 0.5 }
  end
end
