class CollisionManager
  def initialize
    @collidables = []
    @touching = {}
  end

  def add(object)
    @collidables << object
    self
  end

  def reset
    @collidables = []
  end

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

  def serialize = {}
  def inspect = "{}"
  def to_s = "{}"

  private

  def overlap?(a, b)
    a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y
  end

  def pair_key(a, b)
    ids = [ a.object_id, b.object_id ].sort
    "#{ids[0]}-#{ids[1]}"
  end
end
