require_relative "../../test_helper"

class PlayerTest < Minitest::Test
  include GameTest

  def setup
    @player = Player.new
  end

  # --- initial state ---

  def test_starts_with_full_hearts_grounded_and_facing_camera
    assert_equal Player::MAX_HEARTS, @player.hearts
    assert_equal :south, @player.facing
    assert @player.grounded
    refute @player.locked
    refute @player.game_over
  end

  def test_starts_having_not_moved
    refute @player.moved
  end

  def test_starts_having_not_reached_a_platform
    refute @player.reached_platform
  end

  # --- horizontal movement ---

  def test_moves_right_and_faces_east
    start_x = @player.x
    @player.update(build_args(right: true))
    assert_equal start_x + Player::MOVE_SPEED, @player.x
    assert_equal :east, @player.facing
  end

  def test_moves_left_and_faces_west
    start_x = @player.x
    @player.update(build_args(left: true))
    assert_equal start_x - Player::MOVE_SPEED, @player.x
    assert_equal :west, @player.facing
  end

  def test_crawls_while_buffering_then_recovers
    @player.slow(build_args(tick_count: 0))
    start_x = @player.x
    @player.update(build_args(right: true, tick_count: 0))
    assert_equal start_x + Player::SLOW_MOVE_SPEED, @player.x, "moves at crawl speed while lagged"

    after = @player.x
    @player.update(build_args(right: true, tick_count: Player::SLOW_TICKS))
    assert_equal after + Player::MOVE_SPEED, @player.x, "back to full speed once the lag expires"
  end

  def test_idle_faces_south
    @player.update(build_args)
    assert_equal :south, @player.facing
  end

  def test_records_the_first_movement
    @player.update(build_args(right: true))
    assert @player.moved
  end

  def test_idle_does_not_record_movement
    @player.update(build_args)
    refute @player.moved
  end

  def test_clamps_to_the_left_world_edge
    @player.x = 2
    @player.update(build_args(left: true)) # would step to -6
    assert_equal 0, @player.x
  end

  def test_clamps_to_the_right_world_edge
    @player.x = WORLD_W - Player::WIDTH - 2
    @player.update(build_args(right: true)) # would step past the world's right edge
    assert_equal WORLD_W - Player::WIDTH, @player.x
  end

  def test_clamps_to_the_one_screen_welcome_world
    @player.x = SCREEN_W # past the welcome level's single-screen bound
    @player.update(build_args(right: true, level: WelcomeLevel.new))
    assert_equal SCREEN_W - Player::WIDTH, @player.x
  end

  # --- jumping & gravity ---

  def test_jumps_off_the_ground
    @player.update(build_args(space: true))
    refute @player.grounded
    assert_operator @player.y, :>, GROUND_Y
  end

  def test_cannot_launch_a_second_jump_while_airborne
    @player.update(build_args(space: true)) # leave the ground
    @player.vy = 0 # pretend we coasted to the apex
    @player.update(build_args(space: true)) # space held, but not grounded
    assert_equal(-Player::GRAVITY, @player.vy) # only gravity, no fresh launch
  end

  def test_gravity_pulls_down_and_lands_on_the_ground
    @player.y = GROUND_Y + 5
    @player.vy = -10
    @player.grounded = false
    @player.update(build_args)
    assert_equal GROUND_Y, @player.y
    assert_equal 0, @player.vy
    assert @player.grounded
    refute @player.reached_platform # landing on the ground is not a platform
  end

  def test_lands_on_a_platform_while_descending
    platform = Platform.new(x: 180, y: 250, w: 200, h: 30) # top edge at y = 280
    @player.x = 200
    @player.y = 285
    @player.vy = -10
    @player.grounded = false
    @player.update(build_args(platforms: [ platform ]))
    assert_equal 280, @player.y
    assert_equal 0, @player.vy
    assert @player.grounded
    assert @player.reached_platform
  end

  # --- falling through holes ---

  def test_falls_through_a_hole_when_most_of_the_body_overhangs
    hole = Hole.new(x: 200, w: 150) # player sits fully over the gap's left side
    @player.x = 200
    @player.y = GROUND_Y + 5
    @player.vy = -10
    @player.grounded = false
    @player.update(build_args(holes: [ hole ]))
    refute @player.grounded, "no ground over a gap"
    assert_operator @player.y, :<, GROUND_Y, "keeps falling past the floor line"
  end

  def test_lands_normally_when_the_hole_is_elsewhere
    hole = Hole.new(x: 2000, w: 150) # nowhere near the player
    @player.x = 200
    @player.y = GROUND_Y + 5
    @player.vy = -10
    @player.grounded = false
    @player.update(build_args(holes: [ hole ]))
    assert_equal GROUND_Y, @player.y
    assert @player.grounded
  end

  def test_keeps_falling_after_clearing_a_hole_while_descending
    hole = Hole.new(x: 200, w: 150)            # center already past its right edge
    @player.x = 360                            # center 392 > 350 (hole right edge)
    @player.y = -50                            # already sunk below the floor line
    @player.vy = -12
    @player.grounded = false
    @player.update(build_args(holes: [ hole ], right: true))
    refute @player.grounded, "a player mid-fall isn't re-grounded by clearing the gap"
    assert_operator @player.y, :<, GROUND_Y
  end

  def test_stands_on_the_edge_until_three_quarters_of_the_body_overhangs
    # Hole starts just past the player's center, so the center overhangs but only
    # about half the body does — under the forgiving 3/4 threshold, so they stand.
    hole = Hole.new(x: @player.x + @player.w / 2 + 1, w: 150)
    @player.y = GROUND_Y + 5
    @player.vy = -10
    @player.grounded = false
    @player.update(build_args(holes: [ hole ]))
    assert @player.grounded, "still supported until 3/4 of the body overhangs the gap"
    assert_equal GROUND_Y, @player.y
  end

  def test_stands_when_the_center_overhangs_but_less_than_three_quarters_does
    # Body [200,264], hole [220,...] → 44px (~69%) overhangs. The center (232) is
    # over the gap, so the old center rule would drop them; the 3/4 rule holds.
    hole = Hole.new(x: 220, w: 150)
    @player.x = 200
    @player.y = GROUND_Y + 5
    @player.vy = -10
    @player.grounded = false
    @player.update(build_args(holes: [ hole ]))
    assert @player.grounded, "a quarter of the body still has ground under it"
    assert_equal GROUND_Y, @player.y
  end

  # --- stomping enemies ---

  def test_stomping_when_descending_onto_an_enemys_head
    enemy = PasswordEnemy.new(x: @player.x) # top at GROUND_Y + HEIGHT
    @player.y = enemy.y + enemy.h - 6 # feet just below the head, well above the midpoint
    @player.vy = -5 # descending
    assert @player.stomping?(enemy)
  end

  def test_not_stomping_while_rising_into_an_enemy
    enemy = PasswordEnemy.new(x: @player.x)
    @player.y = enemy.y + enemy.h - 6
    @player.vy = 5 # moving up
    refute @player.stomping?(enemy)
  end

  def test_not_stomping_on_a_side_or_ground_hit
    enemy = PasswordEnemy.new(x: @player.x)
    @player.y = GROUND_Y # feet on the ground, low on the enemy's body
    @player.vy = 0
    refute @player.stomping?(enemy)
  end

  def test_bounce_hops_up_and_leaves_the_ground
    @player.grounded = true
    @player.bounce
    assert_equal Player::STOMP_BOUNCE, @player.vy
    refute @player.grounded
  end

  # --- reacting to a collision (Player#on_collision) ---

  def test_bounces_off_a_stomped_enemy
    enemy = PasswordEnemy.new(x: @player.x)
    @player.y = enemy.y + enemy.h - 6 # feet on its head, descending
    @player.vy = -5
    @player.grounded = false
    @player.on_collision(enemy, build_args)

    assert_equal Player::STOMP_BOUNCE, @player.vy
    refute @player.grounded
    assert_equal Player::MAX_HEARTS, @player.hearts, "a stomp costs no heart"
  end

  def test_takes_a_hit_from_a_side_contact
    enemy = TotpEnemy.new(x: @player.x) # feet on the ground, not descending
    @player.on_collision(enemy, build_args(tick_count: 0))

    assert_equal Player::MAX_HEARTS - 1, @player.hearts
    assert @player.locked
    assert_equal :totp, @player.pending_challenge
    assert @player.invincible?(build_args(tick_count: 1)) # blink started
  end

  def test_a_fatal_hit_drops_to_zero_hearts_without_locking
    @player.hearts = 1
    enemy = TotpEnemy.new(x: @player.x)
    @player.on_collision(enemy, build_args(tick_count: 0))

    assert_equal 0, @player.hearts
    refute @player.locked, "the last heart ends the run — Main handles death, not a lock"
    assert_nil @player.pending_challenge
  end

  def test_slows_from_a_buffering_enemy
    enemy = BufferingEnemy.new(x: @player.x)
    @player.on_collision(enemy, build_args(tick_count: 0))

    assert @player.slowed?(1)
    assert_equal Player::MAX_HEARTS, @player.hearts
    refute @player.locked
  end

  def test_a_stomp_on_an_unstompable_enemy_re_auths_instead_of_bouncing
    enemy = TutorialEnemy.new(x: @player.x)
    @player.y = enemy.y + enemy.h - 6 # would be a stomp on a normal enemy
    @player.vy = -5
    @player.grounded = false
    @player.on_collision(enemy, build_args(tick_count: 0))

    assert_equal Player::MAX_HEARTS - 1, @player.hearts, "no bounce — the gate forces the hit"
    assert @player.locked
    refute_equal Player::STOMP_BOUNCE, @player.vy
  end

  def test_ignores_a_collision_while_invincible
    @player.hurt(build_args(tick_count: 0)) # blink window open
    enemy = TotpEnemy.new(x: @player.x)
    @player.on_collision(enemy, build_args(tick_count: 1))

    assert_equal Player::MAX_HEARTS, @player.hearts
    refute @player.locked
  end

  def test_ignores_a_non_enemy_partner
    @player.on_collision(Player.new, build_args)
    assert_equal Player::MAX_HEARTS, @player.hearts
  end

  # --- frozen states ---

  def test_locked_player_ignores_movement
    @player.locked = true
    start_x = @player.x
    @player.update(build_args(right: true))
    assert_equal start_x, @player.x
  end

  def test_game_over_player_ignores_movement
    @player.game_over = true
    start_x = @player.x
    @player.update(build_args(left: true))
    assert_equal start_x, @player.x
  end

  # --- post-hit invincibility ---

  def test_not_invincible_before_being_hit
    refute @player.invincible?(build_args(tick_count: 0))
  end

  def test_invincible_during_the_blink_window
    @player.hurt(build_args(tick_count: 0))
    assert @player.invincible?(build_args(tick_count: 30))
    assert @player.invincible?(build_args(tick_count: Player::BLINK_TICKS - 1))
  end

  def test_invincibility_ends_with_the_blink
    @player.hurt(build_args(tick_count: 0))
    refute @player.invincible?(build_args(tick_count: Player::BLINK_TICKS))
  end

  # --- rendering & serialization ---

  def test_render_emits_the_figure_as_palette_solids
    args = build_args
    @player.render(args, 0)
    assert_equal 0, args.outputs.sprites.length # no PNG art — the figure is primitives
    # 2 legs + torso card (ink + indigo) + neck + head card (ink + skin) + hair +
    # 2 eyes.
    assert_equal 10, args.outputs.solids.length
  end

  def test_serialize_includes_core_fields
    data = @player.serialize
    assert_equal Player::MAX_HEARTS, data[:hearts]
    assert_equal @player.x, data[:x]
    assert_equal false, data[:moved]
    assert_equal false, data[:reached_platform]
  end
end
