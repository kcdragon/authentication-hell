require_relative "../../test_helper"

class CertificateTest < Minitest::Test
  include GameTest

  def setup
    @args = build_args(player: Player.new, tick_count: 0)
  end

  def test_starts_alive
    assert Certificate.new(x: 100).alive
  end

  def test_floats_its_hitbox_above_its_surface
    cert = Certificate.new(x: 320, y: GROUND_Y)
    assert_equal({ x: 320, y: GROUND_Y + Certificate::LIFT,
                   w: Certificate::SIZE, h: Certificate::SIZE }, cert.hitbox)
  end

  def test_collect_is_a_harmless_no_op
    cert = Certificate.new(x: 100)
    assert_nil cert.collect(@args)
    assert_empty @args.state.level.instance_variable_get(:@collected)
  end

  def test_render_draws_the_certificate_sprite
    Certificate.new(x: 100).render(@args)
    assert_equal 1, @args.outputs.sprites.length
    assert_equal "sprites/ui/certificate.png", @args.outputs.sprites.first[:path]
  end

  def test_serialize_describes_the_pickup
    data = Certificate.new(x: 100).serialize
    assert_equal 100, data[:x]
    assert_equal true, data[:alive]
  end
end
