# Tracks a set of collidable objects and, each tick, works out which pairs overlap
# and alerts both — each object then decides how to behave (see #on_collision on the
# entities). It is deliberately type-agnostic: it knows nothing about players, enemies
# or platforms, only that every registered object exposes x/y/w/h (position + size).
# It owns its own state (the registry + which pairs were touching last tick) rather
# than reading anything from args.state; args is forwarded untouched to the objects.
#
# Contact is edge-triggered: a pair is alerted the tick it starts overlapping, not
# every frame it stays overlapping, so a resting overlap fires once.
class CollisionManager
  def initialize
    @collidables = []
    @touching = {} # pair key => true, for the previous tick's overlaps
  end

  # Register an object to collide. Callers refresh the set each tick (#reset then
  # #add) so objects that come and go — enemies spawning, dying — stay in sync.
  def add(object)
    @collidables << object
    self
  end

  # Empty the registry. Leaves the edge-tracking alone (it self-prunes in #resolve),
  # so refreshing the set between ticks doesn't re-fire a still-resting overlap.
  def reset
    @collidables = []
  end

  # Check every pair; on the rising edge of an overlap, alert both objects. args is
  # passed straight through to #on_collision — this class never reads it.
  def resolve(args)
    now = {}
    @collidables.each_with_index do |a, i|
      @collidables.each_with_index do |b, j|
        next unless j > i
        next unless overlap?(a, b)

        key = pair_key(a, b)
        now[key] = true
        next if @touching[key]

        a.on_collision(b, args)
        b.on_collision(a, args)
      end
    end
    @touching = now
  end

  private

  # Axis-aligned bounding-box overlap on any two objects exposing x/y/w/h.
  def overlap?(a, b)
    a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y
  end

  # A stable, order-independent id for a pair, so the same two objects map to the
  # same key whichever order they're checked in.
  def pair_key(a, b)
    ids = [ a.object_id, b.object_id ].sort
    "#{ids[0]}-#{ids[1]}"
  end

  public

  # DragonRuby exports args.state for its dev tools; give it a plain-hash view (see
  # the same pattern on Enemy/Platform). Its state isn't worth exporting, so it's empty.
  def serialize = {}
  def inspect = "{}"
  def to_s = "{}"
end
