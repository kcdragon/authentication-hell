require_relative "../../test_helper"

class PollerTest < Minitest::Test
  URL = "http://test/poll-me".freeze

  def setup
    DR.reset!
    @poller = Network::Poller.new(URL, interval: 30)
  end

  def test_fires_immediately_on_the_first_poll
    @poller.poll(0)
    assert_equal [ URL ], DR.urls
  end

  def test_does_not_refire_while_a_request_is_in_flight
    @poller.poll(0)
    @poller.poll(1)
    assert_equal 1, DR.urls.length
  end

  def test_yields_parsed_json_on_a_200
    @poller.poll(0)
    DR.complete!(URL, body: '{"locked":false}')
    seen = nil
    @poller.poll(1) { |data| seen = data }
    assert_equal({ "locked" => false }, seen)
  end

  def test_swallows_a_failure_and_retries_after_the_interval
    @poller.poll(0)
    DR.complete!(URL, code: 500, body: "")
    called = false
    @poller.poll(1) { called = true }
    refute called

    @poller.poll(2)
    assert_equal 1, DR.urls.length, "waits out the interval before retrying"
    @poller.poll(31)
    assert_equal 2, DR.urls.length
  end

  def test_backs_off_for_the_interval_after_a_success
    @poller.poll(0)
    DR.complete!(URL, body: "{}")
    @poller.poll(10) { nil }

    @poller.poll(39)
    assert_equal 1, DR.urls.length
    @poller.poll(40)
    assert_equal 2, DR.urls.length
  end
end
