require_relative "../../test_helper"

class LevelTest < Minitest::Test
  include GameTest

  def test_build_maps_numbers_to_their_level_classes
    assert_instance_of WelcomeLevel, Level.build(0)
    assert_instance_of PasswordLevel, Level.build(1)
    assert_instance_of TotpLevel, Level.build(2)
    assert_instance_of MainLevel, Level.build(3)
    assert_instance_of GauntletLevel, Level.build(4)
  end

  def test_build_falls_back_to_the_welcome_level_for_an_unknown_number
    assert_instance_of WelcomeLevel, Level.build(99)
  end

  def test_built_levels_report_their_own_number
    [ 0, 1, 2, 3, 4 ].each { |n| assert_equal n, Level.build(n).number }
  end

  def test_poll_network_is_a_no_op_for_levels_that_do_not_talk_to_the_server
    assert_nil MainLevel.new.poll_network(build_args)
  end
end
