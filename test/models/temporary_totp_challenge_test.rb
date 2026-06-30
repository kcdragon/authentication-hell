require "test_helper"

class TemporaryTotpChallengeTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @session = users(:one).sessions.create!
    @challenge = @session.create_temporary_totp_challenge!(secret: ROTP::Base32.random)
  end

  test "register! enrolls with a valid code and rejects a bad one" do
    travel_to Time.at(1_700_000_000) do
      refute @challenge.register!("000000")
      refute @challenge.reload.registered?

      assert @challenge.register!(@challenge.totp.now)
      assert @challenge.reload.registered?
    end
  end

  test "three codes from consecutive windows complete the challenge" do
    @challenge.update!(registered: true)
    base = window_boundary

    travel_to(Time.at(base))      { assert_equal :accepted, @challenge.submit!(@challenge.totp.now) }
    assert_equal 1, @challenge.streak
    travel_to(Time.at(base + 30)) { assert_equal :accepted, @challenge.submit!(@challenge.totp.now) }
    assert_equal 2, @challenge.streak
    travel_to(Time.at(base + 60)) { assert_equal :accepted, @challenge.submit!(@challenge.totp.now) }
    assert_equal 3, @challenge.streak
    assert @challenge.complete?
  end

  test "a skipped window restarts the run of consecutive codes" do
    @challenge.update!(registered: true)
    base = window_boundary

    travel_to(Time.at(base))      { @challenge.submit!(@challenge.totp.now) }
    assert_equal 1, @challenge.streak
    # Skip base+30 entirely; the next valid code is two windows on.
    travel_to(Time.at(base + 90)) { @challenge.submit!(@challenge.totp.now) }
    assert_equal 1, @challenge.streak
    refute @challenge.complete?
  end

  test "replaying the just-used code is a harmless no-op, not a reset" do
    @challenge.update!(registered: true)
    travel_to Time.at(window_boundary) do
      code = @challenge.totp.now
      assert_equal :accepted, @challenge.submit!(code)
      assert_equal 1, @challenge.streak
      assert_equal :replay, @challenge.submit!(code), "the same code can't be replayed"
      assert_equal 1, @challenge.streak, "a replay leaves the streak intact"
    end
  end

  test "an invalid code resets the streak" do
    @challenge.update!(registered: true, streak: 2, last_window: 100, last_at: 3000)
    assert_equal :incorrect, @challenge.submit!("000000")
    assert_equal 0, @challenge.reload.streak
  end

  test "submit! does nothing until registered" do
    assert_equal :incorrect, @challenge.submit!(@challenge.totp.now)
  end

  test "upcoming_codes lists the current code then the next two windows" do
    base = window_boundary
    codes = travel_to(Time.at(base)) { @challenge.upcoming_codes }

    assert_equal 3, codes.length
    travel_to(Time.at(base))      { assert_equal codes[0], @challenge.totp.now }
    travel_to(Time.at(base + 30)) { assert_equal codes[1], @challenge.totp.now }
    travel_to(Time.at(base + 60)) { assert_equal codes[2], @challenge.totp.now }
  end

  private

  # A unix time aligned to a 30s TOTP window so successive +30s steps land in
  # consecutive windows.
  def window_boundary = 1_700_000_000 - (1_700_000_000 % TemporaryTotpChallenge::INTERVAL)
end
