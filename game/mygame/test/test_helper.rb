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

    def urls = @urls ||= []

    def requests = @requests ||= {}

    def http_get(url) = record(url)

    def http_post(url, _body = nil, _headers = nil) = record(url)

    def parse_json(str) = JSON.parse(str)

    def complete!(url, code: 200, body: "{}")
      request = requests.fetch(url)
      request[:complete] = true
      request[:http_response_code] = code
      request[:response_data] = body
      request
    end

    def reset!
      @last_url = nil
      @urls = nil
      @requests = nil
    end

    private

    def record(url)
      @last_url = url
      urls << url
      requests[url] = { complete: false }
    end
  end
end

module GameTest
  # Structs, not Hashes: the engine's hashes quack like attr_accessor — entity
  # code reads `keyboard.left`, which a plain Ruby Hash can't answer.
  KeyDown = Struct.new(:space, :e, :down, :s)
  Keyboard = Struct.new(:left, :right, :key_down)
  Inputs = Struct.new(:keyboard)
  State = Struct.new(:player, :level, :tick_count)
  Outputs = Struct.new(:sprites, :solids, :labels)
  Args = Struct.new(:inputs, :state, :outputs)

  GameStub = Struct.new(:player, :level, :camera_x, :captions_on) do
    def captions_on? = captions_on
  end

  def enemy_level = @enemy_level ||= Level.new(build_game)

  def build_game(player: nil, level: nil, camera_x: 0, captions_on: true)
    GameStub.new(player, level, camera_x, captions_on)
  end

  def build_args(left: false, right: false, e: false,
                 space: false, down: false, s: false, camera_x: 0, platforms: nil, enemies: nil,
                 collectables: nil, player: nil, level: nil, tick_count: 0,
                 holes: nil, captions_on: true)
    level ||= PasswordLevel.new(build_game)
    seed_level_collections(level, platforms: platforms, enemies: enemies,
                           collectables: collectables, holes: holes)
    level.instance_variable_set(:@game, build_game(player: player, level: level,
                                                   camera_x: camera_x, captions_on: captions_on))
    Args.new(
      Inputs.new(Keyboard.new(left, right, KeyDown.new(space, e, down, s))),
      State.new(player, level, tick_count),
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
