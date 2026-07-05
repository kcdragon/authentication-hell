require_relative "../../test_helper"

class CertificateTest < Minitest::Test
  include GameTest

  def setup
    @frame = build_frame(player: Player.new, tick_count: 0)
  end

  def test_starts_alive
    assert Certificate.new(x: 100).alive?
  end

  def test_floats_its_hitbox_above_its_surface
    cert = Certificate.new(x: 320, y: GROUND_Y)
    assert_equal({ x: 320, y: GROUND_Y + Certificate::LIFT,
                   w: Certificate::SIZE, h: Certificate::SIZE }, cert.hitbox)
  end

  def test_on_collision_retires_the_certificate
    cert = Certificate.new(x: 100)
    cert.on_collision(Player.new, @frame)
    refute cert.alive?
  end

  def test_on_collision_ignores_a_non_player_collider
    cert = Certificate.new(x: 100)
    cert.on_collision(Object.new, @frame)
    assert cert.alive?
  end

  def test_collect_is_a_harmless_no_op
    assert_nil Certificate.new(x: 100).collect(Player.new)
  end

  def test_render_draws_the_certificate_sprite
    Certificate.new(x: 100).render(@frame)
    assert_equal 1, @frame.outputs.sprites.length
    assert_equal "sprites/ui/certificate.png", @frame.outputs.sprites.first[:path]
  end
end
