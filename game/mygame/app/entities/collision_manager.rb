# Decides, each tick, whether the player is colliding with something and alerts the
# object it hit — which then decides how to behave (see Enemy#on_collision). This
# first cut covers only the player vs. the level's enemies; platforms/holes stay in
# Player#update and collectables stay in Main's tick.
#
# Stateless on purpose: it reads the level's *live* enemy list every tick rather than
# holding a registry, so mid-level enemy swaps (the welcome level reassigns @enemies),
# deaths, and level changes need no re-registration. Lives on args.state.
class CollisionManager
  # Fire once per contact: alert the enemy on the tick the player first overlaps it
  # (the rising edge), and keep its colliding flag in sync so a resting overlap
  # doesn't re-trigger. Skips the dead, and (via Main) never runs on game-over.
  def resolve(args)
    player = args.state.player
    args.state.level.enemies.each do |enemy|
      next unless enemy.alive

      overlap = intersect?(enemy, player)
      enemy.on_collision(args) if overlap && !enemy.colliding
      enemy.colliding = overlap
    end
  end

  private

  # Axis-aligned bounding-box overlap on any two rects exposing x/y/w/h. Replaces the
  # engine's args.geometry.intersect_rect? so this runs under plain-Ruby tests too.
  def intersect?(a, b)
    a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y
  end

  public

  # DragonRuby exports args.state for its dev tools; give it a plain-hash view (see the
  # same pattern on Enemy/Platform). Stateless, so an empty hash is enough.
  def serialize = {}
  def inspect = "{}"
  def to_s = "{}"
end
