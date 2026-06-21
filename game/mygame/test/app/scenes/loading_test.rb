require_relative "../../test_helper"
require "json"

# DragonRuby's HTTP/JSON globals, stubbed for plain MRI: http_get records the URL
# it was given and hands back an in-flight request handle; parse_json is just JSON.
module DR
  class << self
    attr_accessor :last_url

    def http_get(url)
      @last_url = url
      { complete: false }
    end

    def parse_json(str) = JSON.parse(str)
  end
end

# Exercises the loading scene's engine-free responsibility: polling /game/start and
# resolving the starting level. The drawing path needs the engine, so it's left to
# the build/native run.
class LoadingSceneTest < Minitest::Test
  State = Struct.new(:start_request, :server_base, :start_level, :level)
  Args = Struct.new(:state)

  def poll(start_request: nil)
    args = Args.new(State.new(start_request, "http://test", nil, nil))
    LoadingScene.new(args).send(:poll_start_request)
    args.state
  end

  def complete(code:, body:)
    { complete: true, http_response_code: code, response_data: body }
  end

  def test_kicks_off_the_start_request_on_the_first_tick
    DR.last_url = nil
    state = poll

    assert_equal "http://test/game/start", DR.last_url
    assert_equal({ complete: false }, state.start_request)
    # Still in flight → no level resolved yet.
    assert_nil state.level
  end

  def test_resolves_the_server_start_level_once_the_request_completes
    state = poll(start_request: complete(code: 200, body: '{"start_level":2}'))

    assert_equal 2, state.start_level
    assert_equal 2, state.level.number
    assert_equal :done, state.start_request
  end

  def test_defaults_to_the_welcome_level_when_the_response_omits_a_level
    state = poll(start_request: complete(code: 200, body: "{}"))

    assert_equal 0, state.level.number
    assert_equal :done, state.start_request
  end

  def test_defaults_to_the_welcome_level_when_the_request_fails
    state = poll(start_request: complete(code: 500, body: ""))

    assert_equal 0, state.level.number
    assert_equal :done, state.start_request
  end
end
