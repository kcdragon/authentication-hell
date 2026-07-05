require_relative "../../test_helper"

class PasswordCharacterTest < Minitest::Test
  include GameTest

  def setup
    @frame = build_frame(player: Player.new)
  end

  def test_carries_a_glyph_from_its_class
    PasswordCharacter::CLASSES.each do |klass|
      char = PasswordCharacter.new(x: 100, klass: klass)
      assert_includes PasswordCharacter::UNAMBIGUOUS_GLYPHS.fetch(klass), char.glyph
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

  def test_on_collision_retires_the_padlock_and_stamps_pickup_order
    char = PasswordCharacter.new(x: 100, klass: :symbol, glyph: "#")
    char.on_collision(Player.new, @frame)
    refute char.alive?
    assert char.pickup_order
  end

  def test_on_collision_stamps_grabs_in_order
    player = Player.new
    first = PasswordCharacter.new(x: 100, klass: :upper, glyph: "A")
    second = PasswordCharacter.new(x: 200, klass: :digit, glyph: "7")
    first.on_collision(player, @frame)
    second.on_collision(player, @frame)
    assert_operator first.pickup_order, :<, second.pickup_order
  end

  def test_on_collision_ignores_a_non_player_collider
    char = PasswordCharacter.new(x: 100, klass: :symbol, glyph: "#")
    char.on_collision(Object.new, @frame)
    assert char.alive?
    assert_nil char.pickup_order
  end

  def test_klass_of_recovers_a_glyphs_class
    PasswordCharacter::CLASSES.each do |klass|
      glyph = PasswordCharacter::UNAMBIGUOUS_GLYPHS.fetch(klass).chars.first
      assert_equal klass, PasswordCharacter.klass_of(glyph)
    end
  end
end
