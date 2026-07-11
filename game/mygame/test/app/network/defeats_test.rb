require_relative "../../test_helper"

class NetworkDefeatsTest < Minitest::Test
  def setup
    DR.reset!
  end

  def test_reports_the_kind_in_the_query_string
    Network::Defeats.report("totp")
    assert_equal "http://test/games/defeats?kind=totp", DR.last_url
  end

  def test_each_report_posts_separately
    Network::Defeats.report("buffering")
    Network::Defeats.report("buffering")
    assert_equal 2, DR.urls.count("http://test/games/defeats?kind=buffering")
  end
end
