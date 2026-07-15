require_relative "../../test_helper"

class NetworkLevelsTest < Minitest::Test
  def setup
    DR.reset!
  end

  def test_complete_reports_the_level_and_time_in_the_query_string
    Network::Levels.complete(2, 5000)
    assert_includes DR.urls, "http://test/games/levels/complete?level=2&ms=5000"
  end

  def test_playing_reports_the_level_in_the_query_string
    Network::Levels.playing(3)
    assert_equal "http://test/games/levels/playing?level=3", DR.last_url
  end
end
