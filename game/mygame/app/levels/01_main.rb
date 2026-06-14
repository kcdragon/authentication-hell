# The endless main world the tutorial hands off to. Owns its scene (random enemies
# + a scattered platform field, seeded in setup) and its level-level behavior —
# melee is live (inherited). No on-canvas chrome of its own: controls now live on
# the pause screen.
class MainLevel < Level
  def number = 1

  # Seed the endless world: random enemies and a scattered field of one-way ledges.
  def setup(args)
    args.state.enemies = Enemy.spawn_random(args.state.player.x)
    args.state.platforms = Platform.scatter
    args.state.collectables = []
  end

  def draw(args); end
end
