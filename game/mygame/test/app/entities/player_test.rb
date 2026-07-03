require_relative "../../test_helper"

class PlayerTest < Minitest::Test
  include GameTest

  def setup
    @player = Player.new
  end

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
    @player.update(build_args(left: true))
    assert_equal 0, @player.x
  end

  def test_clamps_to_the_right_world_edge
    @player.x = WORLD_W - Player::WIDTH - 2
    @player.update(build_args(right: true))
    assert_equal WORLD_W - Player::WIDTH, @player.x
  end

  def test_clamps_to_the_one_screen_welcome_world
    @player.x = SCREEN_W
    @player.update(build_args(right: true, level: WelcomeLevel.new))
    assert_equal SCREEN_W - Player::WIDTH, @player.x
  end

  def test_jumps_off_the_ground
    @player.update(build_args(space: true))
    refute @player.grounded
    assert_operator @player.y, :>, GROUND_Y
  end

  def test_cannot_launch_a_second_jump_while_airborne
    @player.update(build_args(space: true))
    @player.vy = 0
    @player.update(build_args(space: true))
    assert_equal(-Player::GRAVITY, @player.vy, "only gravity, no fresh launch")
  end

  def test_gravity_pulls_down_and_lands_on_the_ground
    @player.y = GROUND_Y + 5
    @player.vy = -10
    @player.grounded = false
    @player.update(build_args)
    assert_equal GROUND_Y, @player.y
    assert_equal 0, @player.vy
    assert @player.grounded
    refute @player.reached_platform, "landing on the ground is not a platform"
  end

  def descend_onto(platform, prev_y:)
    @player.instance_variable_set(:@prev_y, prev_y)
    @player.on_collision(platform, build_args)
  end

  def test_lands_on_a_platform_while_descending
    platform = Platform.new(x: 180, y: 250, w: 200, h: 30)
    @player.x = 200
    @player.y = 275
    @player.vy = -10
    @player.grounded = false
    descend_onto(platform, prev_y: 285)
    assert_equal 280, @player.y
    assert_equal 0, @player.vy
    assert @player.grounded
    assert @player.reached_platform
  end

  def test_does_not_land_when_rising_up_through_a_platform
    platform = Platform.new(x: 180, y: 250, w: 200, h: 30)
    @player.x = 200
    @player.y = 275
    @player.vy = 10
    @player.grounded = false
    descend_onto(platform, prev_y: 270)
    refute @player.grounded
    refute @player.reached_platform
  end

  def test_down_arrow_leaves_the_ledge_underfoot
    platform = Platform.new(x: 180, y: 250, w: 200, h: 30)
    @player.x = 200
    @player.y = 280
    @player.vy = 0
    @player.grounded = true
    @player.update(build_args(down: true, platforms: [ platform ]))
    refute @player.grounded, "pressing down releases the ledge"
    assert_operator @player.y, :<, 280, "and starts falling below it"
  end

  def test_s_key_also_leaves_the_ledge_underfoot
    platform = Platform.new(x: 180, y: 250, w: 200, h: 30)
    @player.x = 200
    @player.y = 280
    @player.vy = 0
    @player.grounded = true
    @player.update(build_args(s: true, platforms: [ platform ]))
    refute @player.grounded, "S drops just like the down arrow"
    assert_operator @player.y, :<, 280
  end

  def test_a_dropping_player_falls_through_instead_of_re_landing
    platform = Platform.new(x: 180, y: 250, w: 200, h: 30)
    @player.x = 200
    @player.y = 280
    @player.grounded = true
    @player.update(build_args(down: true, platforms: [ platform ]))
    @player.on_collision(platform, build_args)
    refute @player.grounded, "the ledge underfoot no longer catches a dropping player"
    assert_operator @player.y, :<, 280
  end

  def test_down_arrow_does_nothing_on_the_ground
    @player.y = GROUND_Y
    @player.vy = 0
    @player.grounded = true
    @player.update(build_args(down: true))
    assert @player.grounded, "you can't drop through the world floor"
    assert_equal GROUND_Y, @player.y
  end

  def test_drop_completes_and_lands_on_the_ground_below
    platform = Platform.new(x: 180, y: 250, w: 200, h: 30)
    @player.x = 200
    @player.y = 280
    @player.grounded = true
    @player.update(build_args(down: true, platforms: [ platform ]))
    40.times { @player.update(build_args) }
    assert_equal GROUND_Y, @player.y, "settles on the floor once the drop has cleared"
    assert @player.grounded
  end

  # A stomp mid-drop flips @vy upward; the drop must clear so landing works again
  # rather than leaving the player permanently falling through every ledge.
  def test_a_dropping_player_who_bounces_can_land_again
    platform = Platform.new(x: 180, y: 250, w: 200, h: 30)
    @player.x = 200
    @player.y = 280
    @player.grounded = true
    @player.update(build_args(down: true, platforms: [ platform ]))
    @player.bounce
    @player.update(build_args)
    @player.vy = -10
    @player.y = 275
    descend_onto(platform, prev_y: 285)
    assert @player.grounded, "landing works again once the drop has cleared"
    assert_equal 280, @player.y
  end

  def test_falls_through_a_hole_when_most_of_the_body_overhangs
    hole = Hole.new(x: 200, w: 150)
    @player.x = 200
    @player.y = GROUND_Y + 5
    @player.vy = -10
    @player.grounded = false
    @player.update(build_args(holes: [ hole ]))
    refute @player.grounded, "no ground over a gap"
    assert_operator @player.y, :<, GROUND_Y, "keeps falling past the floor line"
  end

  def test_lands_normally_when_the_hole_is_elsewhere
    hole = Hole.new(x: 2000, w: 150)
    @player.x = 200
    @player.y = GROUND_Y + 5
    @player.vy = -10
    @player.grounded = false
    @player.update(build_args(holes: [ hole ]))
    assert_equal GROUND_Y, @player.y
    assert @player.grounded
  end

  def test_keeps_falling_after_clearing_a_hole_while_descending
    hole = Hole.new(x: 200, w: 150)
    @player.x = 360
    @player.y = -50
    @player.vy = -12
    @player.grounded = false
    @player.update(build_args(holes: [ hole ], right: true))
    refute @player.grounded, "a player mid-fall isn't re-grounded by clearing the gap"
    assert_operator @player.y, :<, GROUND_Y
  end

  def test_stands_on_the_edge_until_three_quarters_of_the_body_overhangs
    just_past_the_players_center = @player.x + @player.w / 2 + 1
    hole = Hole.new(x: just_past_the_players_center, w: 150)
    @player.y = GROUND_Y + 5
    @player.vy = -10
    @player.grounded = false
    @player.update(build_args(holes: [ hole ]))
    assert @player.grounded, "still supported until 3/4 of the body overhangs the gap"
    assert_equal GROUND_Y, @player.y
  end

  def test_stands_when_the_center_overhangs_but_less_than_three_quarters_does
    hole = Hole.new(x: 220, w: 150)
    @player.x = 200
    @player.y = GROUND_Y + 5
    @player.vy = -10
    @player.grounded = false
    @player.update(build_args(holes: [ hole ]))
    assert @player.grounded, "a quarter of the body still has ground under it"
    assert_equal GROUND_Y, @player.y
  end

  def test_stomping_when_descending_onto_an_enemys_head
    enemy = PasswordEnemy.new(x: @player.x, level: enemy_level)
    @player.y = enemy.y + enemy.h - 6
    @player.vy = -5
    assert @player.stomping?(enemy)
  end

  def test_not_stomping_while_rising_into_an_enemy
    enemy = PasswordEnemy.new(x: @player.x, level: enemy_level)
    @player.y = enemy.y + enemy.h - 6
    @player.vy = 5
    refute @player.stomping?(enemy)
  end

  def test_not_stomping_on_a_side_or_ground_hit
    enemy = PasswordEnemy.new(x: @player.x, level: enemy_level)
    @player.y = GROUND_Y
    @player.vy = 0
    refute @player.stomping?(enemy)
  end

  def test_still_stomping_after_bouncing_this_tick
    enemy = PasswordEnemy.new(x: @player.x, level: enemy_level)
    @player.y = enemy.y + enemy.h - 6
    @player.bounce
    assert @player.stomping?(enemy), "the bounce flipped vy positive, but a second enemy underfoot is still a stomp"
  end

  def test_bounce_hops_up_and_leaves_the_ground
    @player.grounded = true
    @player.bounce
    assert_equal Player::STOMP_BOUNCE, @player.vy
    refute @player.grounded
  end

  def test_bounces_off_a_stomped_enemy
    enemy = PasswordEnemy.new(x: @player.x, level: enemy_level)
    @player.y = enemy.y + enemy.h - 6
    @player.vy = -5
    @player.grounded = false
    @player.on_collision(enemy, build_args)

    assert_equal Player::STOMP_BOUNCE, @player.vy
    refute @player.grounded
    assert_equal Player::MAX_HEARTS, @player.hearts, "a stomp costs no heart"
  end

  def test_takes_a_hit_from_a_side_contact
    enemy = TotpEnemy.new(x: @player.x, level: enemy_level)
    @player.on_collision(enemy, build_args(tick_count: 0))

    assert_equal Player::MAX_HEARTS - 1, @player.hearts
    assert @player.locked
    assert_equal :totp, @player.pending_challenge
    assert @player.invincible?(build_args(tick_count: 1))
  end

  def test_a_fatal_hit_drops_to_zero_hearts_without_locking
    @player.hearts = 1
    enemy = TotpEnemy.new(x: @player.x, level: enemy_level)
    @player.on_collision(enemy, build_args(tick_count: 0))

    assert_equal 0, @player.hearts
    refute @player.locked, "the last heart ends the run — Main handles death, not a lock"
    assert_nil @player.pending_challenge
  end

  def test_slows_from_a_buffering_enemy
    enemy = BufferingEnemy.new(x: @player.x, level: enemy_level)
    @player.on_collision(enemy, build_args(tick_count: 0))

    assert @player.slowed?(1)
    assert_equal Player::MAX_HEARTS, @player.hearts
    refute @player.locked
  end

  def test_a_stomp_on_an_unstompable_enemy_re_auths_instead_of_bouncing
    enemy = TutorialEnemy.new(x: @player.x, level: enemy_level)
    @player.y = enemy.y + enemy.h - 6
    @player.vy = -5
    @player.grounded = false
    @player.on_collision(enemy, build_args(tick_count: 0))

    assert_equal Player::MAX_HEARTS - 1, @player.hearts, "no bounce — the gate forces the hit"
    assert @player.locked
    refute_equal Player::STOMP_BOUNCE, @player.vy
  end

  def test_ignores_a_collision_while_invincible
    @player.hurt(build_args(tick_count: 0))
    enemy = TotpEnemy.new(x: @player.x, level: enemy_level)
    @player.on_collision(enemy, build_args(tick_count: 1))

    assert_equal Player::MAX_HEARTS, @player.hearts
    refute @player.locked
  end

  def test_ignores_a_non_enemy_partner
    @player.on_collision(Player.new, build_args)
    assert_equal Player::MAX_HEARTS, @player.hearts
  end

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

  def test_render_emits_the_figure_as_palette_solids
    args = build_args
    @player.render(args, 0)
    assert_equal 0, args.outputs.sprites.length, "no PNG art — the figure is primitives"
    assert_equal 10, args.outputs.solids.length,
                 "2 legs + torso card (ink + indigo) + neck + head card (ink + skin) + hair + 2 eyes"
  end

  def test_serialize_includes_core_fields
    data = @player.serialize
    assert_equal Player::MAX_HEARTS, data[:hearts]
    assert_equal @player.x, data[:x]
    assert_equal false, data[:moved]
    assert_equal false, data[:reached_platform]
  end
end
