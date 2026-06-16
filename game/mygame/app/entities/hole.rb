# A Mario-style pit: a gap in the ground the player falls through. Owns its x-span;
# Player#over_hole? reads it so the ground check lets the player drop, and Main's tick
# docks a heart and respawns them just to the left (no re-auth — that's for enemies).
# Lives in args.state.holes; levels without pits leave it []. Visual-only otherwise:
# it breaks the floor lip and cuts a dark recess into the control-bar "floor."
class Hole
  W = 150          # gap width — under a jump's ~320px reach, so a pit is clearable
  COUNT = 4

  attr_accessor :x, :w

  # Evenly-spaced gaps across the mid-world, one per slot (so they spread out), each
  # nudged by a random offset so they don't line up with the platforms/pickups. Kept
  # clear of the spawn area (start_x) and the right wall (end_margin) so the player
  # never loads onto a pit or loses one right at the exit.
  def self.scatter(count: COUNT, world_w: WORLD_W, start_x: 700, end_margin: 700)
    slot = ((world_w - end_margin) - start_x) / count
    count.times.map do |i|
      x = start_x + i * slot + rand([ slot - W, 0 ].max)
      new(x: x, w: W)
    end
  end

  def initialize(x:, w:)
    @x = x
    @w = w
  end

  EDGE_W = 3 # ink rim on each side of the gap

  # Break the floor over the gap: punch it open with the PAPER background (so you see
  # "through" the floor, the same wall as above the ground line) the full depth of the
  # control-bar band — from the bottom of the screen up through the floor line, erasing
  # the dark bar and its lip there — then frame it with ink rims so the pit walls read
  # crisply against the dark floor. World x is shifted by the camera; drawn between the
  # floor band and the scrubber/transport (main.rb draw_control_bar) so the pit cuts
  # through the band while the video controls still draw legibly over it.
  def render(args, camera_x = 0)
    sx = @x - camera_x
    args.outputs.solids << { x: sx, y: 0, w: @w, h: GROUND_Y,
                             r: PAPER[0], g: PAPER[1], b: PAPER[2] }
    [ sx, sx + @w - EDGE_W ].each do |ex|
      args.outputs.solids << { x: ex, y: 0, w: EDGE_W, h: GROUND_Y,
                               r: INK[0], g: INK[1], b: INK[2] }
    end
  end

  # DragonRuby exports args.state for its dev tools; give it a plain-hash view (see
  # the same pattern on Platform).
  def serialize = { x: @x, w: @w }
  def inspect = serialize.to_s
  def to_s = serialize.to_s
end
