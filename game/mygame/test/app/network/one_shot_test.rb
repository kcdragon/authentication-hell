require_relative "../../test_helper"

class OneShotTest < Minitest::Test
  URL = "http://test/report".freeze

  def setup
    DR.reset!
    @shot = Network::OneShot.new
  end

  def test_posts_and_reports_pending
    refute @shot.pending?
    @shot.post(URL)
    assert @shot.pending?
    assert_equal [ URL ], DR.urls
  end

  def test_update_is_quiet_while_in_flight
    @shot.post(URL)
    called = false
    @shot.update { called = true }
    refute called
    assert @shot.pending?
  end

  def test_update_yields_parsed_data_once_complete_and_clears
    @shot.post(URL)
    DR.complete!(URL, body: '{"ok":true}')
    seen = nil
    @shot.update { |data| seen = data }
    assert_equal({ "ok" => true }, seen)
    refute @shot.pending?
  end

  def test_update_yields_nil_on_a_failure_but_still_clears
    @shot.post(URL)
    DR.complete!(URL, code: 500, body: "")
    yielded = :not_called
    @shot.update { |data| yielded = data }
    assert_nil yielded
    refute @shot.pending?
  end
end
