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

  def test_setup_pulls_the_player_back_and_clears_any_carried_progress
    @args.state.player.x = 1100 # roamed right during the tutorial
    @args.state.player.collected_password_characters = { upper: "A" } # stale, from a prior run
    @level.setup(@args)

    assert_equal 0, @args.state.player.x
    assert_equal 0, @args.state.camera_x
    assert_empty @args.state.player.collected_password_characters
  end

  def test_setup_scatters_at_least_one_padlock_of_every_class
    @level.setup(@args)
    assert(@args.state.collectables.all? { |c| c.is_a?(PasswordCharacter) })
    classes = @args.state.collectables.map(&:klass).uniq
    assert_equal PasswordCharacter::CLASSES.sort, classes.sort, "every character class must appear"
  end

  def test_setup_perches_a_padlock_on_every_platform_and_keeps_a_floor_row
    @level.setup(@args)
    tops = @args.state.platforms.map { |p| p.y + p.h }
    perched = @args.state.collectables.select { |c| tops.include?(c.y) }
    grounded = @args.state.collectables.select { |c| c.y == GROUND_Y }

    assert_equal @args.state.platforms.length, perched.length, "one padlock per platform top"
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

  def test_does_not_complete_at_the_wall_without_every_character
    @level.setup(@args)
    @args.state.player.x = WORLD_W - Player::WIDTH # at the exit, but empty-handed
    @level.update(@args)
    refute @level.complete?
  end

  def test_does_not_complete_with_every_character_but_short_of_the_wall
    @level.setup(@args)
    collect_all
    @args.state.player.x = 3000 # holds the set, but hasn't reached the exit
    @level.update(@args)
    refute @level.complete?
  end

  def test_completes_with_every_character_at_the_wall_and_hands_off_to_main
    @level.setup(@args)
    collect_all
    @args.state.player.x = WORLD_W - Player::WIDTH
    @level.update(@args)

    assert @level.complete?
    assert_instance_of MainLevel, @level.next_level
  end

  def test_password_targets_drives_the_hud_tray
    assert_equal PasswordCharacter::CLASSES, @level.password_targets
  end

  def test_draw_emits_a_prompt
    @level.draw(@args)
    refute_empty @args.outputs.labels
  end

  def test_serialize_names_the_level
    assert_equal "PasswordLevel", @level.serialize[:level]
  end

  private

  def collect_all
    PasswordCharacter::CLASSES.each { |klass| @args.state.player.collected_password_characters[klass] = "x" }
  end
end
