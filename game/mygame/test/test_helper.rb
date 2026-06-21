# Plain-Ruby (MRI + Minitest) test harness for the game entities. The DragonRuby
# engine binary is gitignored and macOS-only, so these tests never load it: the
# entities are ordinary Ruby objects whose only engine touchpoint is the
# duck-typed `args`, which we stub below. That keeps them runnable anywhere Ruby
# is — including CI on Linux.
require "minitest/autorun"

# Load the game's files exactly as main.rb does — through app/requires.rb. The
# engine resolves "app/..." against the mygame/ root; here we put that root on the
# load path first so the same requires resolve under plain MRI. main.rb is itself
# engine-only and never loaded.
$LOAD_PATH.unshift(File.expand_path("..", __dir__))
require "app/requires.rb"

# Minimal stand-ins for DragonRuby's `args`. The entities only read a handful of
# input/state fields and append to output arrays, so plain Structs suffice. Use
# Structs (not Hashes) because the engine's hashes quack like attr_accessor —
# code reads `keyboard.left`, not `keyboard[:left]` — which plain Ruby hashes don't.
module GameTest
  KeyDown = Struct.new(:space)
  Keyboard = Struct.new(:left, :right, :key_down)
  Inputs = Struct.new(:keyboard)
  # captions_on gates the closed caption a level draws (via Caption) in its #draw path.
  State = Struct.new(:camera_x, :platforms, :enemies, :collectables, :player, :level,
                     :tick_count, :captions_on, :holes)
  Outputs = Struct.new(:sprites, :solids, :labels)
  Args = Struct.new(:inputs, :state, :outputs)

  # Build an `args` double for a single tick. Defaults mean "no input". The level
  # defaults to MainLevel (the full-width world) so the player clamps to WORLD_W
  # like it does in the running game; pass a WelcomeLevel to exercise the
  # one-screen bound.
  def build_args(left: false, right: false,
                 space: false, camera_x: 0, platforms: [], enemies: nil,
                 collectables: nil, player: nil, level: MainLevel.new, tick_count: 0,
                 holes: [])
    Args.new(
      Inputs.new(Keyboard.new(left, right, KeyDown.new(space))),
      State.new(camera_x, platforms, enemies, collectables, player, level, tick_count, nil, holes),
      Outputs.new([], [], [])
    )
  end
end
