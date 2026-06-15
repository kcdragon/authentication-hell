require_relative "../../test_helper"

class LevelTest < Minitest::Test
  include GameTest

  def test_build_maps_numbers_to_their_level_classes
    assert_instance_of TutorialLevel, Level.build(0)
    assert_instance_of PasswordLevel, Level.build(1)
    assert_instance_of MainLevel, Level.build(2)
    assert_instance_of GauntletLevel, Level.build(3)
  end

  def test_build_falls_back_to_the_tutorial_for_an_unknown_number
    assert_instance_of TutorialLevel, Level.build(99)
  end

  def test_built_levels_report_their_own_number
    [ 0, 1, 2, 3 ].each { |n| assert_equal n, Level.build(n).number }
  end
end
