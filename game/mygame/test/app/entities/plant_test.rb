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

  def test_can_root_on_a_platform_top
    plant = Plant.new(x: 0, kind: :pink_bush, y: 250)
    args = build_args
    plant.render(args, 0)

    assert_equal 250, args.outputs.sprites.first[:y]
  end

  def test_scale_shrinks_the_render_size
    full = Plant.new(x: 0, kind: :poppy_bush)
    small = Plant.new(x: 0, kind: :poppy_bush, scale: 0.5)

    assert_equal full.w / 2, small.w
    assert_equal full.h / 2, small.h
  end

  def test_an_unknown_kind_raises
    assert_raises(KeyError) { Plant.new(x: 0, kind: :tumbleweed) }
  end
end
