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

  # Must fire every frame a pair still overlaps — the player re-settles onto
  # platforms each tick; skipping repeat pairs silently breaks landing.
  def resolve(args)
    @collidables.each_with_index do |a, i|
      @collidables.each_with_index do |b, j|
        next unless j > i
        next unless Aabb.overlap?(a, b)

        a.on_collision(b, args)
        b.on_collision(a, args)
      end
    end
  end
end
