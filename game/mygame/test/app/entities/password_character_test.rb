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

  def test_every_class_has_a_face_and_text_color
    PasswordCharacter::CLASSES.each do |klass|
      assert PasswordCharacter::CLASS_FACE.key?(klass), "no face color for #{klass}"
      assert PasswordCharacter::CLASS_INK.key?(klass), "no text color for #{klass}"
    end
  end

  def test_an_explicit_glyph_overrides_the_random_one
    char = PasswordCharacter.new(x: 100, klass: :upper, glyph: "Q")
    assert_equal "Q", char.glyph
  end

  def test_floats_a_chip_hitbox_above_its_surface
    char = PasswordCharacter.new(x: 320, klass: :digit)
    inset = (PasswordCharacter::SIZE - PasswordCharacter::CHIP) / 2
    assert_equal({ x: 320 + inset, y: GROUND_Y + PasswordCharacter::FLOAT_GAP,
                   w: PasswordCharacter::CHIP, h: PasswordCharacter::CHIP }, char.hitbox)
  end

  def test_collect_records_the_class_and_glyph_on_the_player
    char = PasswordCharacter.new(x: 100, klass: :symbol, glyph: "#")
    char.collect(@args)
    assert_equal [ "#" ], @args.state.player.collected_password_characters[:symbol]
  end

  def test_collect_accumulates_each_glyph_of_a_class
    PasswordCharacter.new(x: 100, klass: :upper, glyph: "A").collect(@args)
    PasswordCharacter.new(x: 200, klass: :upper, glyph: "Z").collect(@args)
    assert_equal [ "A", "Z" ], @args.state.player.collected_password_characters[:upper]
  end

  def test_serialize_describes_the_pickup
    data = PasswordCharacter.new(x: 100, klass: :lower, glyph: "m").serialize
    assert_equal :lower, data[:klass]
    assert_equal "m", data[:glyph]
    assert_equal true, data[:alive]
  end
end
