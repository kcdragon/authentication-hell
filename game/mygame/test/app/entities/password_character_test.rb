require_relative "../../test_helper"

class PasswordCharacterTest < Minitest::Test
  include GameTest

  def setup
    @args = build_args(player: Player.new)
  end

  def test_carries_a_glyph_from_its_class
    PasswordCharacter::CLASSES.each do |klass|
      char = PasswordCharacter.new(x: 100, klass: klass)
      assert_includes PasswordCharacter::GLYPHS.fetch(klass), char.glyph
    end
  end

  def test_an_explicit_glyph_overrides_the_random_one
    char = PasswordCharacter.new(x: 100, klass: :upper, glyph: "Q")
    assert_equal "Q", char.glyph
  end

  def test_sits_on_the_ground_with_a_full_body_hitbox
    char = PasswordCharacter.new(x: 320, klass: :digit)
    assert_equal({ x: 320, y: GROUND_Y, w: PasswordCharacter::SIZE, h: PasswordCharacter::SIZE }, char.hitbox)
  end

  def test_collect_records_the_class_and_glyph_on_the_player
    char = PasswordCharacter.new(x: 100, klass: :symbol, glyph: "#")
    char.collect(@args)
    assert_equal "#", @args.state.player.collected_password_characters[:symbol]
  end

  def test_collect_keeps_the_first_glyph_of_a_class
    PasswordCharacter.new(x: 100, klass: :upper, glyph: "A").collect(@args)
    PasswordCharacter.new(x: 200, klass: :upper, glyph: "Z").collect(@args)
    assert_equal "A", @args.state.player.collected_password_characters[:upper]
  end

  def test_serialize_describes_the_pickup
    data = PasswordCharacter.new(x: 100, klass: :lower, glyph: "m").serialize
    assert_equal :lower, data[:klass]
    assert_equal "m", data[:glyph]
    assert_equal true, data[:alive]
  end
end
