# Plain-Ruby (MRI + Minitest) harness: the DragonRuby engine binary is gitignored
# and macOS-only, so these tests never load it — the entities' only engine
# touchpoint is the duck-typed `args`, stubbed below.
require "minitest/autorun"
require "json"

$LOAD_PATH.unshift(File.expand_path("..", __dir__))
require "app/requires.rb"

$server_base = "http://test"

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

module GameTest
  # Structs, not Hashes: the engine's hashes quack like attr_accessor — entity
  # code reads `keyboard.left`, which a plain Ruby Hash can't answer.
  KeyDown = Struct.new(:space, :e, :down, :s)
  Keyboard = Struct.new(:left, :right, :key_down)
  Inputs = Struct.new(:keyboard)
  State = Struct.new(:camera_x, :player, :level, :tick_count, :captions_on)
  Outputs = Struct.new(:sprites, :solids, :labels)
  Args = Struct.new(:inputs, :state, :outputs)

  def enemy_level = @enemy_level ||= Level.new

  def build_args(left: false, right: false, e: false,
                 space: false, down: false, s: false, camera_x: 0, platforms: nil, enemies: nil,
                 collectables: nil, player: nil, level: PasswordLevel.new, tick_count: 0,
                 holes: nil)
    seed_level_collections(level, platforms: platforms, enemies: enemies,
                           collectables: collectables, holes: holes)
    Args.new(
      Inputs.new(Keyboard.new(left, right, KeyDown.new(space, e, down, s))),
      State.new(camera_x, player, level, tick_count, nil),
      Outputs.new([], [], [])
    )
  end

  def seed_level_collections(level, platforms:, enemies:, collectables:, holes:)
    level.instance_variable_set(:@platforms, platforms) if platforms
    level.instance_variable_set(:@enemies, enemies) if enemies
    level.instance_variable_set(:@collectables, collectables) if collectables
    level.instance_variable_set(:@holes, holes) if holes
  end
end
