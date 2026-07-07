require_relative "../../test_helper"

class EditorLevelsNetworkTest < Minitest::Test
  def setup
    DR.reset!
    @client = Network::EditorLevels.new
  end

  def test_fetch_index_hits_the_editor_levels_endpoint
    @client.fetch_index
    assert_equal "http://test/editor/levels", DR.last_url
    assert @client.pending?
  end

  def test_fetch_level_hits_the_slug_url
    @client.fetch_level("level-5")
    assert_equal "http://test/editor/levels/level-5", DR.last_url
  end

  def test_save_posts_the_raw_json_body
    @client.save("{\"slug\":\"level-5\"}")
    assert_equal "http://test/editor/levels", DR.last_url
    assert_equal "{\"slug\":\"level-5\"}", DR.requests[DR.last_url][:body]
  end

  def test_promote_posts_to_the_member_promote_url
    @client.promote("level-5")
    assert_equal "http://test/editor/levels/level-5/promote", DR.last_url
    assert @client.pending?
  end

  def test_update_yields_parsed_data_on_200
    @client.fetch_index
    DR.complete!(DR.last_url, body: "{\"next_slug\":\"level-5\",\"levels\":[]}")

    result = nil
    @client.update { |r| result = r }

    assert result[:ok]
    assert_equal "level-5", result[:data]["next_slug"]
    refute @client.pending?
  end

  def test_update_reports_failures_with_the_status_code
    @client.save("{}")
    DR.complete!(DR.last_url, code: 422, body: "{}")

    result = nil
    @client.update { |r| result = r }

    refute result[:ok]
    assert_equal 422, result[:code]
  end

  def test_update_does_nothing_while_the_request_is_in_flight
    @client.fetch_index
    called = false
    @client.update { called = true }
    refute called
    assert @client.pending?
  end
end
