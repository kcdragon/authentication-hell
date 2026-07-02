# Type-agnostic contact detector: each tick, callers refill its bag (reset + add) and
# it alerts both sides of every overlapping pair, leaving each object's #on_collision
# to own its reaction — it knows nothing about what the objects are.
class CollisionManager
  def initialize
    @collidables = []
  end

  def add(object)
    @collidables << object
    self
  end

  def reset
    @collidables = []
  end

  # Alert both sides of every overlapping pair, every frame they overlap — a player
  # resting on a platform must re-settle each tick, and a once-only reactor (an enemy)
  # opts out by removing itself from the bag after its hit.
  def resolve(args)
    @collidables.each_with_index do |a, i|
      @collidables.each_with_index do |b, j|
        next unless j > i
        next unless overlap?(a, b)

        a.on_collision(b, args)
        b.on_collision(a, args)
      end
    end
  end

  def serialize = {}
  def inspect = "{}"
  def to_s = "{}"

  private

  def overlap?(a, b)
    a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y
  end
end
