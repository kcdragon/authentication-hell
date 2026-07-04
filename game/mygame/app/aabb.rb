module Aabb
  def self.overlap?(a, b)
    a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y
  end

  def self.overlap_width(a, b)
    [ a.x + a.w, b.x + b.w ].min - [ a.x, b.x ].max
  end
end
