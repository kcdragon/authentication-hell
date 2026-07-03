# Plain-Ruby (MRI + Minitest) test harness for the game entities. The DragonRuby
# engine binary is gitignored and macOS-only, so these tests never load it: the
# entities are ordinary Ruby objects whose only engine touchpoint is the
# duck-typed `args`, which we stub below. That keeps them runnable anywhere Ruby
# is — including CI on Linux.
require "minitest/autorun"
require "json"

# Load the game's files exactly as main.rb does — through app/requires.rb. The
# engine resolves "app/..." against the mygame/ root; here we put that root on the
# load path first so the same requires resolve under plain MRI. main.rb is itself
# engine-only and never loaded.
$LOAD_PATH.unshift(File.expand_path("..", __dir__))
require "app/requires.rb"

# Seed the server-origin global that Main normally sets from config on the first tick,
# so network code (e.g. the loading scene) builds URLs without an engine file read.
$server_base = "http://test"

# DragonRuby's HTTP/JSON globals, stubbed for plain MRI: the http_* calls record the
# last URL and hand back an in-flight (never-completing) request handle; parse_json is
# just JSON. Lets code that reaches the Network layer (the loading scene, the TOTP
# level's #update) run under test without the engine.
module DR
  class << self
    attr_accessor :last_url

    def http_get(url)
      @last_url = url
      { complete: false }
    end

    def http_post(url, _body = nil, _headers = nil)
      @last_url = url
      { complete: false }
    end

    def parse_json(str) = JSON.parse(str)
  end
end

# Minimal stand-ins for DragonRuby's `args`. The entities only read a handful of
# input/state fields and append to output arrays, so plain Structs suffice. Use
# Structs (not Hashes) because the engine's hashes quack like attr_accessor —
# code reads `keyboard.left`, not `keyboard[:left]` — which plain Ruby hashes don't.
module GameTest
  KeyDown = Struct.new(:space, :e, :down, :s)
  Keyboard = Struct.new(:left, :right, :key_down)
  Inputs = Struct.new(:keyboard)
  # captions_on gates the closed caption a level draws (via Caption) in its #draw path.
  # The level owns its own entities (enemies/platforms/collectables/holes) — build_args
  # seeds them onto the level, not the shared state.
  State = Struct.new(:camera_x, :player, :level, :tick_count, :captions_on)
  Outputs = Struct.new(:sprites, :solids, :labels)
  Args = Struct.new(:inputs, :state, :outputs)

  # Build an `args` double for a single tick. Defaults mean "no input". The level
  # defaults to PasswordLevel (a full-width world) so the player clamps to WORLD_W
  # like it does in the running game; pass a WelcomeLevel to exercise the
  # one-screen bound. Any passed platforms/enemies/collectables/holes are seeded
  # onto the level (where they live), so the code under test reads them there.
  def build_args(left: false, right: false, e: false,
                 space: false, down: false, s: false, camera_x: 0, platforms: nil, enemies: nil,
                 collectables: nil, player: nil, level: PasswordLevel.new, tick_count: 0,
                 holes: nil)
    # The level's collections are read-only in production (only the level seeds them
    # in #setup); poke them directly here to stage a specific scene for a single tick.
    level.instance_variable_set(:@platforms, platforms) if platforms
    level.instance_variable_set(:@enemies, enemies) if enemies
    level.instance_variable_set(:@collectables, collectables) if collectables
    level.instance_variable_set(:@holes, holes) if holes
    Args.new(
      Inputs.new(Keyboard.new(left, right, KeyDown.new(space, e, down, s))),
      State.new(camera_x, player, level, tick_count, nil),
      Outputs.new([], [], [])
    )
  end
end
