require_relative "../../test_helper"

class RubyPickupTest < Minitest::Test
  include GameTest

  def test_starts_alive
    assert RubyPickup.new(x: 100, y: GROUND_Y).alive?
  end

  def test_on_collision_with_the_player_retires_and_records_pickup_order
    player = Player.new
    ruby = RubyPickup.new(x: player.x, y: player.y)
    ruby.on_collision(player, build_args(player: player))

    refute ruby.alive?
    refute_nil ruby.pickup_order
  end

  def test_collecting_leaves_the_player_untouched
    player = Player.new
    hearts_before = player.hearts
    RubyPickup.new(x: player.x, y: player.y).on_collision(player, build_args(player: player))

    assert_equal hearts_before, player.hearts
  end

  def test_ignores_a_non_player_collider
    ruby = RubyPickup.new(x: 100, y: GROUND_Y)
    ruby.on_collision(Object.new, build_args)
    assert ruby.alive?
  end

  def test_render_draws_the_gem_sprite_in_camera_space
    ruby = RubyPickup.new(x: 500, y: GROUND_Y)
    args = build_args(tick_count: 0)
    ruby.render(args, 200)

    sprite = args.outputs.sprites.first
    assert_equal 300, sprite[:x]
    assert_equal "sprites/ui/ruby.png", sprite[:path]
  end

  def test_serialize_describes_the_pickup
    data = RubyPickup.new(x: 100, y: GROUND_Y).serialize
    assert_equal 100, data[:x]
    assert_equal true, data[:alive]
  end
end
