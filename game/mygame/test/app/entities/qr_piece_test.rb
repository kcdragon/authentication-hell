require_relative "../../test_helper"

class QrPieceTest < Minitest::Test
  include GameTest

  def test_starts_alive
    assert piece(index: 0).alive?
  end

  def test_on_collision_with_the_player_retires_and_records_pickup_order
    player = Player.new
    fragment = QrPiece.new(x: player.x, y: player.y, index: 1)
    fragment.on_collision(player, build_args(player: player))

    refute fragment.alive?
    refute_nil fragment.pickup_order
  end

  def test_collecting_leaves_the_player_untouched
    player = Player.new
    hearts_before = player.hearts
    QrPiece.new(x: player.x, y: player.y, index: 1).on_collision(player, build_args(player: player))

    assert_equal hearts_before, player.hearts
  end

  def test_ignores_a_non_player_collider
    fragment = piece(index: 0)
    fragment.on_collision(Object.new, build_args)
    assert fragment.alive?
  end

  def test_each_index_maps_to_its_own_quadrant_sprite
    paths = (0..3).map { |i| piece(index: i).sprite_path }

    assert_equal paths, paths.uniq
    paths.each do |path|
      assert File.exist?(File.expand_path("../../../#{path}", __dir__)), "missing sprite asset #{path}"
    end
  end

  def test_render_draws_the_quadrant_sprite_on_an_ink_backing_in_camera_space
    args = build_args(tick_count: 0)
    piece(index: 1, x: 500).render(args, 200)

    backing = args.outputs.solids.first
    sprite = args.outputs.sprites.first
    assert_equal 300 - QrPiece::BORDER, backing[:x]
    assert_equal [ INK[0], INK[1], INK[2] ], [ backing[:r], backing[:g], backing[:b] ]
    assert_equal 300, sprite[:x]
    assert_equal "sprites/ui/qr_piece_1.png", sprite[:path]
  end

  def test_serialize_names_the_index
    data = piece(index: 3).serialize
    assert_equal 3, data[:index]
    assert_equal true, data[:alive]
  end

  private

  def piece(index:, x: 100) = QrPiece.new(x: x, y: GROUND_Y, index: index)
end
