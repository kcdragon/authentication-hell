# The endless main world the tutorial hands off to. Owns its scene (random enemies
# + a scattered platform field, seeded in setup) and its level-level behavior —
# melee is live (inherited), with a controls reminder.
class MainLevel < Level
  def number = 1

  # Seed the endless world: random enemies and a scattered field of one-way ledges.
  def setup(args)
    args.state.enemies = Enemy.spawn_random(args.state.player.x)
    args.state.platforms = Platform.scatter
    args.state.collectables = []
  end

  # The unlocked controls reminder, shown while the player is free to roam.
  def draw(args)
    args.outputs.labels << { x: 640, y: 640,
                             text: "(arrow keys or A/D to move, space to jump, click to swing)",
                             size_px: 18, font: FONT_MONO,
                             r: MUTED[0], g: MUTED[1], b: MUTED[2],
                             anchor_x: 0.5, anchor_y: 0.5 }
  end
end
