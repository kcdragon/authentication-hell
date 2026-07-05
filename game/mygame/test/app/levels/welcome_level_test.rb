require_relative "../../test_helper"

class WelcomeLevelTest < Minitest::Test
  include GameTest

  def setup
    @level = WelcomeLevel.new(build_game)
    @player = Player.new
    @frame = build_frame(player: @player, level: @level)
  end

  def test_starts_mid_screen_not_at_the_world_edge
    assert_equal 200, @level.start_x
  end

  def test_setup_seeds_a_reachable_ledge_and_no_enemy_yet
    @level.setup(@frame)
    assert_empty @level.enemies

    assert_equal 1, @level.platforms.length
    platform = @level.platforms.first
    assert_includes Platform::TIERS, platform.y + platform.h
  end

  def test_setup_leaves_the_ground_flat_with_no_pits
    @level.setup(@frame)
    assert_empty @level.holes
  end

  def test_update_holds_the_enemy_until_the_player_reaches_the_platform
    @level.setup(@frame)
    @player.instance_variable_set(:@reached_platform, false)
    @level.update(@frame)
    assert_empty @level.enemies
  end

  def test_update_sends_in_a_leftbound_password_enemy_from_the_right_edge
    @level.setup(@frame)
    @player.instance_variable_set(:@reached_platform, true)
    @level.update(@frame)

    assert_equal 1, @level.enemies.length
    enemy = @level.enemies.first
    assert_instance_of TutorialEnemy, enemy
    assert_equal :password, enemy.auth
    assert_equal SCREEN_W, enemy.x
    assert_operator enemy.vx, :<, 0
    assert_equal enemy.x, enemy.patrol_max_x, "won't wander back past its entry"
  end

  def test_update_spawns_the_enemy_only_once
    @level.setup(@frame)
    @player.instance_variable_set(:@reached_platform, true)
    @level.update(@frame)
    @level.enemies.first.alive = false
    @level.update(@frame)
    assert_equal 1, @level.enemies.length
  end

  def test_grabbing_the_heart_heals_but_does_not_complete
    heal
    assert @level.send(:healed?)
    refute @level.complete?
  end

  def test_update_sends_a_rightbound_enemy_in_from_the_left_after_the_heal
    @level.setup(@frame)
    heal
    @level.update(@frame)

    assert_equal 1, @level.enemies.length
    enemy = @level.enemies.first
    assert_instance_of PasswordEnemy, enemy
    assert_equal(-Enemy::WIDTH, enemy.x)
    assert_operator enemy.vx, :>, 0
    assert_equal enemy.x, enemy.patrol_min_x, "won't wander back past its entry"
    assert_equal SCREEN_W, enemy.patrol_max_x, "bounded to the screen, can't escape right"
  end

  def test_defeating_the_combat_enemy_drops_a_certificate_but_does_not_complete
    @level.setup(@frame)
    heal
    @level.update(@frame)
    @level.enemies.first.alive = false
    @level.update(@frame)

    certs = @level.collectables.select { |c| c.is_a?(Certificate) }
    assert_equal 1, certs.length, "a certificate drops once the enemy is down"
    refute @level.complete?, "but the welcome level isn't done until it's picked up"
  end

  def test_completes_once_the_certificate_is_collected
    @level.setup(@frame)
    heal
    @level.update(@frame)
    @level.enemies.first.alive = false
    @level.update(@frame)

    @level.collectables.find { |c| c.is_a?(Certificate) }.alive = false
    @level.update(@frame)

    assert @level.complete?
  end

  def test_combat_enemy_defeat_does_not_complete_while_locked
    @level.setup(@frame)
    heal
    @level.update(@frame)
    @level.enemies.first.alive = false
    @player.lock!(:password)
    @level.update(@frame)

    refute @level.complete?
  end

  def test_opening_beat_prompts_movement_and_is_ready_immediately
    @level.setup(@frame)
    assert @level.dialogue_ready?(@frame)
    assert_equal [ "Move with A / D or arrow keys" ], @level.current_dialogue(@frame)
  end

  def test_jump_hint_waits_until_the_player_has_moved
    @level.setup(@frame)
    @level.advance_dialogue
    refute @level.dialogue_ready?(@frame)
    assert_nil @level.current_dialogue(@frame)

    @player.instance_variable_set(:@moved, true)
    @level.dialogue_ready?(@frame) # eligible now — stamps the delay start
    @frame = build_frame(player: @player, level: @level, tick_count: WelcomeLevel::DIALOGUE_DELAY)
    assert @level.dialogue_ready?(@frame)
    assert_equal [ "Press Space to jump onto the ledge" ], @level.current_dialogue(@frame)
  end

  def test_a_reached_beat_waits_a_short_delay_before_its_card_shows
    @level.setup(@frame)
    @level.advance_dialogue
    @player.instance_variable_set(:@moved, true)
    refute @level.dialogue_ready?(@frame), "the card holds back briefly after the milestone"
    assert_nil @level.current_dialogue(@frame)

    @frame = build_frame(player: @player, level: @level, tick_count: WelcomeLevel::DIALOGUE_DELAY)
    assert @level.dialogue_ready?(@frame)
  end

  def test_dialogue_leaves_the_scene_visible
    refute @level.dialogue_hides_scene?
  end

  def test_no_dialogue_once_every_beat_is_dismissed
    @level.setup(@frame)
    6.times { @level.advance_dialogue }
    refute @level.dialogue_remaining?(@frame)
    assert_nil @level.current_dialogue(@frame)
  end


  def test_number_is_zero
    assert_equal 0, @level.number
  end

  def test_world_fits_one_screen
    assert_equal SCREEN_W, @level.world_w
  end

  private

  def heal
    retired_heart = HeartPickup.new(x: 0, y: GROUND_Y)
    retired_heart.alive = false
    @level.collectables << retired_heart
  end
end
