# The open main world the password level hands off to. Owns its scene (random enemies +
# a scattered platform field, seeded in setup) and its level-level behavior — melee
# is live (inherited). No on-canvas chrome of its own: controls now live on the
# pause screen. Cleared by collecting the certificate at the world's right exit, which
# hands off to the gauntlet finale.
class MainLevel < Level
  def number = 2

  def title = "The Open Web"

  def accent = GREEN

  # Seed the world: random enemies, a scattered field of one-way ledges, and the
  # completion certificate at the right exit.
  def setup(args)
    args.state.enemies = Enemy.spawn_random(args.state.player.x)
    args.state.platforms = Platform.scatter
    args.state.holes = Hole.scatter
    args.state.collectables = [ certificate_at_exit ]
  end

  # Latch completion once the player picks up the certificate (#complete? runs without
  # args, so the check has to happen here, where the tick hands us args).
  def update(args)
    @cleared = true if certificate_collected?(args)
  end

  def complete? = @cleared == true

  def next_level = GauntletLevel.new
end
