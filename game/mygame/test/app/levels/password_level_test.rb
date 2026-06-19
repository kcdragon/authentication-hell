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

  def test_melee_is_live
    assert @level.melee?
  end

  def test_starts_at_the_left_edge
    assert_equal 0, @level.start_x
  end

  def test_setup_clears_any_carried_password_progress
    @args.state.player.collected_password_characters = { upper: "A" } # stale, from a prior run
    @level.setup(@args)

    assert_empty @args.state.player.collected_password_characters
  end

  def test_setup_scatters_at_least_one_padlock_of_every_class
    @level.setup(@args)
    assert(@args.state.collectables.all? { |c| c.is_a?(PasswordCharacter) })
    classes = @args.state.collectables.map(&:klass).uniq
    assert_equal PasswordCharacter::CLASSES.sort, classes.sort, "every character class must appear"
  end

  def test_setup_perches_a_padlock_on_each_staircase_top_and_keeps_a_floor_row
    @level.setup(@args)
    padlock_tops = @args.state.platforms.select(&:holds_password).map { |p| p.y + p.h }
    perched = @args.state.collectables.select { |c| padlock_tops.include?(c.y) }
    grounded = @args.state.collectables.select { |c| c.y == GROUND_Y }

    assert_equal @args.state.platforms.count(&:holds_password), perched.length, "one padlock per staircase top"
    refute_empty grounded, "a row still sits on the floor"
  end

  def test_setup_seeds_only_totp_and_passkey_hazards
    @level.setup(@args)
    refute_empty @args.state.enemies
    auths = @args.state.enemies.map(&:auth).uniq.sort
    assert_equal %i[passkey totp], auths, "password enemies are collectables here, not hazards"
  end

  def test_hazards_never_spawn_on_top_of_the_player
    @level.setup(@args)
    nearest_reach = @args.state.enemies.map { |e| e.x - Enemy::PATROL_RANGE }.min
    assert nearest_reach > @args.state.player.x + Player::WIDTH,
           "nearest hazard patrol reach (#{nearest_reach}) must clear the player's right edge"
  end

  def test_setup_lays_a_platform_field
    @level.setup(@args)
    refute_empty @args.state.platforms
  end

  def test_setup_scatters_pits_within_the_world
    @level.setup(@args)
    refute_empty @args.state.holes
    @args.state.holes.each do |hole|
      assert_operator hole.x, :>=, 0
      assert_operator hole.x + hole.w, :<=, @level.world_w
    end
  end

  def test_no_certificate_and_no_completion_without_every_character
    @level.setup(@args)
    @level.update(@args)
    refute(@args.state.collectables.any? { |c| c.is_a?(Certificate) }, "no exit certificate yet")
    refute @level.complete?
  end

  def test_one_of_each_class_is_not_enough_to_finish
    @level.setup(@args)
    PasswordCharacter::CLASSES.each { |klass| @args.state.player.collected_password_characters[klass] = [ "x" ] }
    @level.update(@args)

    refute(@args.state.collectables.any? { |c| c.is_a?(Certificate) },
           "the complexity rule wants #{PasswordLevel::REQUIRED_PER_CLASS} of each, not one")
    refute @level.complete?
  end

  def test_spawns_the_certificate_once_every_character_is_held
    @level.setup(@args)
    collect_all
    @level.update(@args)

    certs = @args.state.collectables.select { |c| c.is_a?(Certificate) }
    assert_equal 1, certs.length, "the exit certificate appears once the set is complete"
    refute @level.complete?, "but not finished until it's picked up"

    @level.update(@args) # idempotent: doesn't spawn a second one
    assert_equal 1, @args.state.collectables.count { |c| c.is_a?(Certificate) }
  end

  def test_completes_when_the_certificate_is_collected_and_hands_off_to_main
    @level.setup(@args)
    collect_all
    @level.update(@args) # spawns the certificate
    @args.state.collectables.find { |c| c.is_a?(Certificate) }.alive = false
    @level.update(@args)

    assert @level.complete?
    assert_instance_of MainLevel, @level.next_level
  end

  def test_password_targets_drives_the_hud_tray
    assert_equal PasswordCharacter::CLASSES, @level.password_targets
  end

  def test_draw_emits_a_caption_prompt
    @args.state.captions_on = true
    @level.draw(@args)
    refute_empty @args.outputs.labels
  end

  def test_serialize_names_the_level
    assert_equal "PasswordLevel", @level.serialize[:level]
  end

  private

  def collect_all
    PasswordCharacter::CLASSES.each do |klass|
      @args.state.player.collected_password_characters[klass] = Array.new(PasswordLevel::REQUIRED_PER_CLASS, "x")
    end
  end
end
