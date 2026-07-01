require_relative "../../test_helper"

class WelcomeLevelTest < Minitest::Test
  include GameTest

  def setup
    @level = WelcomeLevel.new
    @args = build_args(player: Player.new)
  end

  def test_starts_mid_screen_not_at_the_world_edge
    assert_equal 200, @level.start_x
  end

  def test_melee_is_off_during_the_reauth_lesson
    refute @level.melee?
  end

  def test_melee_turns_on_after_the_heal
    @level.on_collect(@args)
    assert @level.melee?
  end

  def test_setup_seeds_a_reachable_ledge_and_no_enemy_yet
    @level.setup(@args)
    assert_empty @level.enemies

    assert_equal 1, @level.platforms.length
    platform = @level.platforms.first
    assert_includes Platform::TIERS, platform.y + platform.h
  end

  def test_setup_leaves_the_ground_flat_with_no_pits
    @level.setup(@args)
    assert_empty @level.holes
  end

  def test_update_holds_the_enemy_until_the_player_reaches_the_platform
    @level.setup(@args)
    @args.state.player.reached_platform = false
    @level.update(@args)
    assert_empty @level.enemies
  end

  def test_update_sends_in_a_leftbound_password_enemy_from_the_right_edge
    @level.setup(@args)
    @args.state.player.reached_platform = true
    @args.state.camera_x = 0
    @level.update(@args)

    assert_equal 1, @level.enemies.length
    enemy = @level.enemies.first
    assert_equal :password, enemy.auth
    assert_equal SCREEN_W, enemy.x          # enters at the right edge of the view
    assert_operator enemy.vx, :<, 0          # marching left
    assert_equal enemy.x, enemy.patrol_max_x # won't wander back past its entry
  end

  def test_update_spawns_the_enemy_only_once
    @level.setup(@args)
    @args.state.player.reached_platform = true
    @level.update(@args)
    @level.enemies.first.alive = false  # player defeated/passed it
    @level.update(@args)
    assert_equal 1, @level.enemies.length
  end

  def test_on_collect_heals_but_does_not_complete
    @level.on_collect(@args)
    refute @level.complete?
  end

  def test_update_sends_a_rightbound_enemy_in_from_the_left_after_the_heal
    @level.setup(@args)
    @args.state.camera_x = 0
    @level.on_collect(@args)
    @level.update(@args)

    assert_equal 1, @level.enemies.length
    enemy = @level.enemies.first
    assert_equal :password, enemy.auth
    assert_equal(-Enemy::WIDTH, enemy.x)     # enters just off the left edge
    assert_operator enemy.vx, :>, 0          # marching right
    assert_equal enemy.x, enemy.patrol_min_x # won't wander back past its entry
    assert_equal SCREEN_W, enemy.patrol_max_x # bounded to the screen, can't escape right
  end

  def test_defeating_the_combat_enemy_drops_a_certificate_but_does_not_complete
    @level.setup(@args)
    @level.on_collect(@args)
    @level.update(@args)                     # spawns the combat enemy
    @level.enemies.first.alive = false  # player stomped it
    @level.update(@args)

    certs = @level.collectables.select { |c| c.is_a?(Certificate) }
    assert_equal 1, certs.length, "a certificate drops once the enemy is down"
    refute @level.complete?, "but the welcome level isn't done until it's picked up"
  end

  def test_completes_once_the_certificate_is_collected
    @level.setup(@args)
    @level.on_collect(@args)
    @level.update(@args)
    @level.enemies.first.alive = false
    @level.update(@args)                     # drops the certificate

    @level.collectables.find { |c| c.is_a?(Certificate) }.alive = false
    @level.update(@args)

    assert @level.complete?
  end

  def test_combat_enemy_defeat_does_not_complete_while_locked
    @level.setup(@args)
    @level.on_collect(@args)
    @level.update(@args)
    @level.enemies.first.alive = false
    @args.state.player.locked = true         # bumped it — re-auth in progress
    @level.update(@args)

    refute @level.complete?
  end

  def test_opening_beat_prompts_movement_and_is_ready_immediately
    @level.setup(@args)
    assert @level.dialogue_ready?(@args)
    assert_equal [ "Move with A / D or arrow keys" ], @level.current_dialogue(@args)
  end

  def test_jump_hint_waits_until_the_player_has_moved
    @level.setup(@args)
    @level.advance_dialogue                  # dismiss the move hint
    refute @level.dialogue_ready?(@args)     # hasn't moved yet — the world plays on
    assert_nil @level.current_dialogue(@args)

    @args.state.player.moved = true
    @level.dialogue_ready?(@args)            # eligible now — stamps the delay start
    @args.state.tick_count += WelcomeLevel::DIALOGUE_DELAY
    assert @level.dialogue_ready?(@args)
    assert_equal [ "Press Space to jump onto the ledge" ], @level.current_dialogue(@args)
  end

  def test_a_reached_beat_waits_a_short_delay_before_its_card_shows
    @level.setup(@args)
    @level.advance_dialogue                  # dismiss the move hint
    @args.state.player.moved = true          # milestone reached this tick...
    refute @level.dialogue_ready?(@args)     # ...but the card holds back briefly
    assert_nil @level.current_dialogue(@args)

    @args.state.tick_count += WelcomeLevel::DIALOGUE_DELAY
    assert @level.dialogue_ready?(@args)
  end

  def test_dialogue_leaves_the_scene_visible
    refute @level.dialogue_hides_scene?
  end

  def test_no_dialogue_once_every_beat_is_dismissed
    @level.setup(@args)
    6.times { @level.advance_dialogue }
    refute @level.dialogue_remaining?(@args)
    assert_nil @level.current_dialogue(@args)
  end

  def test_serialize_names_the_level
    assert_equal "WelcomeLevel", @level.serialize[:level]
  end

  def test_number_is_zero
    assert_equal 0, @level.number
  end

  def test_world_fits_one_screen
    assert_equal SCREEN_W, @level.world_w
  end
end
