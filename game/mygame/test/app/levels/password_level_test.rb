require_relative "../../test_helper"

class PasswordLevelTest < Minitest::Test
  include GameTest

  def setup
    @level = PasswordLevel.new
    @args = build_args(player: Player.new, level: @level)
  end

  def test_number_is_one
    assert_equal 1, @level.number
  end

  def test_world_is_the_full_width
    assert_equal WORLD_W, @level.world_w
  end

  def test_starts_at_the_left_edge
    assert_equal 0, @level.start_x
  end

  def test_setup_clears_any_carried_password_progress
    stage([ "A" ]) # stale, from a prior run
    @level.setup(@args)

    assert_empty @level.send(:collected)
  end

  def test_setup_scatters_at_least_one_padlock_of_every_class
    @level.setup(@args)
    assert(@level.collectables.all? { |c| c.is_a?(PasswordCharacter) })
    classes = @level.collectables.map(&:klass).uniq
    assert_equal PasswordCharacter::CLASSES.sort, classes.sort, "every character class must appear"
  end

  def test_setup_perches_a_padlock_on_each_staircase_top_and_keeps_a_floor_row
    @level.setup(@args)
    padlock_tops = @level.platforms.select(&:holds_password).map { |p| p.y + p.h }
    perched = @level.collectables.select { |c| padlock_tops.include?(c.y) }
    grounded = @level.collectables.select { |c| c.y == GROUND_Y }

    assert_equal @level.platforms.count(&:holds_password), perched.length, "one padlock per staircase top"
    refute_empty grounded, "a row still sits on the floor"
  end

  def test_setup_seeds_only_totp_and_passkey_hazards
    @level.setup(@args)
    refute_empty @level.enemies
    auths = @level.enemies.map(&:auth).uniq.sort
    assert_equal %i[passkey totp], auths, "password enemies are collectables here, not hazards"
  end

  def test_hazards_never_spawn_on_top_of_the_player
    @level.setup(@args)
    nearest_reach = @level.enemies.map { |e| e.x - Enemy::PATROL_RANGE }.min
    assert nearest_reach > @args.state.player.x + Player::WIDTH,
           "nearest hazard patrol reach (#{nearest_reach}) must clear the player's right edge"
  end

  def test_setup_lays_a_platform_field
    @level.setup(@args)
    refute_empty @level.platforms
  end

  def test_setup_scatters_pits_within_the_world
    @level.setup(@args)
    refute_empty @level.holes
    @level.holes.each do |hole|
      assert_operator hole.x, :>=, 0
      assert_operator hole.x + hole.w, :<=, @level.world_w
    end
  end

  def test_no_certificate_and_no_completion_without_every_character
    @level.setup(@args)
    @level.update(@args)
    refute(@level.collectables.any? { |c| c.is_a?(Certificate) }, "no exit certificate yet")
    refute @level.complete?
  end

  def test_one_of_each_class_is_not_enough_to_finish
    @level.setup(@args)
    stage(PasswordCharacter::CLASSES.map { |klass| glyph_for(klass) })
    @level.update(@args)

    refute(@level.collectables.any? { |c| c.is_a?(Certificate) },
           "the complexity rule wants #{PasswordLevel::REQUIRED_PER_CLASS} of each, not one")
    refute @level.complete?
  end

  def test_a_full_but_unbalanced_password_is_rejected_and_reset
    @level.setup(@args)
    # Eight characters, but 3 upper / 2 lower / 2 digit / only 1 symbol — invalid.
    stage(%w[A B C a b 2 3 !]) # the retired padlocks stand in for a picked-clean field
    @level.update(@args)

    refute(@level.collectables.any? { |c| c.is_a?(Certificate) }, "an invalid password doesn't finish")
    assert_empty @level.send(:collected), "the rejected password is cleared"
    assert(@level.collectables.all?(&:alive?), "every padlock respawns at its spot")
    assert @level.validation_error_active?(@args), "the invalid-password banner is showing"
  end

  def test_a_valid_password_does_not_trigger_a_validation_error
    @level.setup(@args)
    collect_all
    @level.update(@args)

    refute @level.validation_error_active?(@args)
  end

  def test_validation_error_banner_expires_after_its_window
    @level.setup(@args)
    stage(Array.new(PasswordLevel::PASSWORD_LENGTH, "A")) # all one class
    @level.update(@args) # fails at tick 0
    assert @level.validation_error_active?(@args)

    later = build_args(player: @args.state.player, level: @level,
                       tick_count: PasswordLevel::VALIDATION_ERROR_TICKS + 1)
    refute @level.validation_error_active?(later)
  end

  def test_spawns_the_certificate_once_every_character_is_held
    @level.setup(@args)
    collect_all
    @level.update(@args)

    certs = @level.collectables.select { |c| c.is_a?(Certificate) }
    assert_equal 1, certs.length, "the exit certificate appears once the set is complete"
    refute @level.complete?, "but not finished until it's picked up"

    @level.update(@args) # idempotent: doesn't spawn a second one
    assert_equal 1, @level.collectables.count { |c| c.is_a?(Certificate) }
  end

  def test_completes_when_the_certificate_is_collected_and_hands_off_to_totp
    @level.setup(@args)
    collect_all
    @level.update(@args) # spawns the certificate
    @level.collectables.find { |c| c.is_a?(Certificate) }.alive = false
    @level.update(@args)

    assert @level.complete?
    assert_instance_of TotpLevel, @level.next_level
    refute @level.last?, "the password level hands off — it isn't the final level"
  end

  def test_draw_hud_paints_a_slot_for_every_required_character
    @level.draw_hud(@args)
    slots = @args.outputs.solids.count / 2 # each slot is an ink border + a face
    assert_equal PasswordCharacter::CLASSES.length * PasswordLevel::REQUIRED_PER_CLASS, slots
  end

  def test_draw_hud_colors_a_filled_slot_by_its_class
    stage([ "A" ])
    @level.draw_hud(@args)
    faces = @args.outputs.solids.map { |s| [ s[:r], s[:g], s[:b] ] }
    assert_includes faces, PasswordCharacter::CLASS_FACE.fetch(:upper)
  end

  def test_draw_emits_a_caption_prompt
    @args.state.captions_on = true
    @level.draw(@args)
    refute_empty @args.outputs.labels
  end

  def test_draw_shows_the_invalid_password_banner_while_the_error_is_active
    @level.setup(@args)
    stage(Array.new(PasswordLevel::PASSWORD_LENGTH, "A")) # all one class
    @level.update(@args) # rejected → banner active
    @level.draw(@args)

    assert(@args.outputs.labels.any? { |l| l[:text] == "INVALID PASSWORD" })
  end

  def test_serialize_names_the_level
    assert_equal "PasswordLevel", @level.serialize[:level]
  end

  private

  # Simulate a collected password: replace the field with retired padlocks carrying the
  # given glyphs, in pickup order — exactly what #collected reads back from the world.
  def stage(glyphs)
    staged = glyphs.each_with_index.map do |g, i|
      char = PasswordCharacter.new(x: 0, klass: PasswordCharacter.klass_of(g), glyph: g)
      char.alive = false
      char.instance_variable_set(:@pickup_order, i)
      char
    end
    @level.instance_variable_set(:@collectables, staged)
  end

  def collect_all
    stage(PasswordCharacter::CLASSES.flat_map { |klass| Array.new(PasswordLevel::REQUIRED_PER_CLASS, glyph_for(klass)) })
  end

  def glyph_for(klass) = PasswordCharacter::GLYPHS.fetch(klass).chars.first
end
