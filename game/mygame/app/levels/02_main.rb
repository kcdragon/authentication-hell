# The open main world the password level hands off to. Owns its scene (random enemies +
# a scattered platform field, seeded in setup) and its level-level behavior — melee
# is live (inherited). No on-canvas chrome of its own: controls now live on the
# pause screen. Cleared by walking to the world's right wall, which hands off to the
# gauntlet finale.
class MainLevel < Level
  def number = 2

  # Seed the world: random enemies and a scattered field of one-way ledges.
  def setup(args)
    args.state.enemies = Enemy.spawn_random(args.state.player.x)
    args.state.platforms = Platform.scatter
    args.state.collectables = []
  end

  # Latch completion once the player reaches the far wall (#complete? runs without
  # args, so the check has to happen here, where the tick hands us args).
  def update(args)
    @cleared = true if reached_end?(args)
  end

  def complete? = @cleared == true

  def next_level = GauntletLevel.new
end
