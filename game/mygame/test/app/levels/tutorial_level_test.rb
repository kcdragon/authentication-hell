require_relative "../../test_helper"

class TutorialLevelTest < Minitest::Test
  include GameTest

  def setup
    @level = TutorialLevel.new
    @args = build_args(player: Player.new)
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
    assert_empty @args.state.enemies

    assert_equal 1, @args.state.platforms.length
    platform = @args.state.platforms.first
    assert_includes Platform::TIERS, platform.y + platform.h
  end

  def test_update_holds_the_enemy_until_the_player_reaches_the_platform
    @level.setup(@args)
    @args.state.player.reached_platform = false
    @level.update(@args)
    assert_empty @args.state.enemies
  end

  def test_update_sends_in_a_leftbound_password_enemy_from_the_right_edge
    @level.setup(@args)
    @args.state.player.reached_platform = true
    @args.state.camera_x = 0
    @level.update(@args)

    assert_equal 1, @args.state.enemies.length
    enemy = @args.state.enemies.first
    assert_equal :password, enemy.auth
    assert_equal SCREEN_W, enemy.x          # enters at the right edge of the view
    assert_operator enemy.vx, :<, 0          # marching left
    assert_equal enemy.x, enemy.patrol_max_x # won't wander back past its entry
  end

  def test_update_spawns_the_enemy_only_once
    @level.setup(@args)
    @args.state.player.reached_platform = true
    @level.update(@args)
    @args.state.enemies.first.alive = false  # player defeated/passed it
    @level.update(@args)
    assert_equal 1, @args.state.enemies.length
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

    assert_equal 1, @args.state.enemies.length
    enemy = @args.state.enemies.first
    assert_equal :password, enemy.auth
    assert_equal(-Enemy::WIDTH, enemy.x)     # enters just off the left edge
    assert_operator enemy.vx, :>, 0          # marching right
    assert_equal enemy.x, enemy.patrol_min_x # won't wander back past its entry
  end

  def test_complete_once_the_combat_enemy_is_defeated
    @level.setup(@args)
    @level.on_collect(@args)
    @level.update(@args)                     # spawns the combat enemy
    @args.state.enemies.first.alive = false  # player swung the keyboard at it
    @level.update(@args)

    assert @level.complete?
  end

  def test_combat_enemy_defeat_does_not_complete_while_locked
    @level.setup(@args)
    @level.on_collect(@args)
    @level.update(@args)
    @args.state.enemies.first.alive = false
    @args.state.player.locked = true         # bumped it — re-auth in progress
    @level.update(@args)

    refute @level.complete?
  end

  def test_draw_emits_a_prompt
    @level.draw(@args)
    refute_empty @args.outputs.labels
  end

  def test_serialize_names_the_level
    assert_equal "TutorialLevel", @level.serialize[:level]
  end

  def test_number_is_zero
    assert_equal 0, @level.number
  end
end
