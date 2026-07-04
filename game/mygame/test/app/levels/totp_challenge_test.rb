require_relative "../../test_helper"

class TotpChallengeTest < Minitest::Test
  def setup
    @challenge = TotpChallenge.new
  end

  def test_starts_dormant
    refute @challenge.active?
    refute @challenge.started?
    refute @challenge.registered?
    refute @challenge.complete?
    refute @challenge.submitting?
    assert_equal 0, @challenge.streak
    assert_empty @challenge.entered
    assert_nil @challenge.pending_code
  end

  def test_submit_assembles_the_code_clears_the_tray_and_freezes_entry
    [ 1, 2, 3, 4, 5, 6 ].each { |digit| @challenge.enter(digit) }
    @challenge.submit!

    assert_equal "123456", @challenge.pending_code
    assert_empty @challenge.entered
    assert @challenge.submitting?
  end

  def test_the_network_takes_the_code_and_resolves_the_submit
    @challenge.enter(9)
    @challenge.submit!
    @challenge.code_taken!
    assert_nil @challenge.pending_code
    assert @challenge.submitting?, "still frozen until the server answers"

    @challenge.submit_resolved!
    refute @challenge.submitting?
  end

  def test_record_status_tracks_only_the_keys_present
    @challenge.record_status("registered" => true)
    assert @challenge.registered?
    assert_equal 0, @challenge.streak

    @challenge.record_status("streak" => 2, "complete" => true)
    assert_equal 2, @challenge.streak
    assert @challenge.complete?
    assert @challenge.registered?, "an absent key leaves the last value alone"
  end
end
