require_relative "../../test_helper"

class PlantTest < Minitest::Test
  include GameTest

  def test_each_kind_has_a_sprite_and_render_size
    Plant::KINDS.each_key do |kind|
      plant = Plant.new(x: 0, kind: kind)
      assert_match(/\Asprites\/plants\/[a-z-]+\.png\z/, plant.path)
      assert_operator plant.w, :>, 0
      assert_operator plant.h, :>, 0
    end
  end

  def test_render_draws_on_the_ground_in_camera_space
    plant = Plant.new(x: 700, kind: :coreopsis)
    args = build_args
    plant.render(args, 100)

    sprite = args.outputs.sprites.first
    assert_equal 600, sprite[:x]
    assert_equal GROUND_Y, sprite[:y]
  end

  def test_an_unknown_kind_raises
    assert_raises(KeyError) { Plant.new(x: 0, kind: :tumbleweed) }
  end
end
