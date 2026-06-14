# Plain-Ruby (MRI + Minitest) test harness for the game entities. The DragonRuby
# engine binary is gitignored and macOS-only, so these tests never load it: the
# entities are ordinary Ruby objects whose only engine touchpoint is the
# duck-typed `args`, which we stub below. That keeps them runnable anywhere Ruby
# is — including CI on Linux.
require "minitest/autorun"

# Scene constants the entities reference at runtime, extracted from main.rb (which
# is engine-only and can't load here). Load them before the entity under test.
require_relative "../app/constants"
require_relative "../app/entities/player"
require_relative "../app/entities/enemy"
require_relative "../app/entities/platform"
require_relative "../app/entities/enemies/totp"
require_relative "../app/entities/enemies/passkey"
require_relative "../app/entities/enemies/password"
require_relative "../app/levels/level"
require_relative "../app/levels/00_tutorial"
require_relative "../app/levels/01_main"
require_relative "../app/levels/02_gauntlet"

# Minimal stand-ins for DragonRuby's `args`. The entities only read a handful of
# input/state fields and append to output arrays, so plain Structs suffice. Use
# Structs (not Hashes) because the engine's hashes quack like attr_accessor —
# code reads `mouse.x`, not `mouse[:x]` — which plain Ruby hashes don't.
module GameTest
  Mouse = Struct.new(:click, :x)
  KeyDown = Struct.new(:space)
  Keyboard = Struct.new(:left, :right, :key_down)
  Inputs = Struct.new(:mouse, :keyboard)
  State = Struct.new(:camera_x, :platforms, :enemies, :collectables, :player, :level)
  Outputs = Struct.new(:sprites, :solids, :labels)
  Args = Struct.new(:inputs, :state, :outputs)

  # Build an `args` double for a single tick. Defaults mean "no input". The level
  # defaults to MainLevel (the full-width world) so the player clamps to WORLD_W
  # like it does in the running game; pass a TutorialLevel to exercise the
  # one-screen bound.
  def build_args(mouse_click: false, mouse_x: 0, left: false, right: false,
                 space: false, camera_x: 0, platforms: [], enemies: nil,
                 collectables: nil, player: nil, level: MainLevel.new)
    Args.new(
      Inputs.new(Mouse.new(mouse_click, mouse_x),
                 Keyboard.new(left, right, KeyDown.new(space))),
      State.new(camera_x, platforms, enemies, collectables, player, level),
      Outputs.new([], [], [])
    )
  end
end
