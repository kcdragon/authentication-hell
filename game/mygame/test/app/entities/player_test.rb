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

  def test_starts_not_swinging_with_keyboard_on_the_right
    assert_equal 0, @player.swing_ticks_left
    assert_equal :east, @player.swing_dir
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

  # --- keyboard swing ---

  def test_click_starts_a_full_length_swing
    @player.update(build_args(mouse_click: true))
    assert_equal Player::SWING_TICKS, @player.swing_ticks_left
  end

  def test_swing_aims_the_way_the_player_faces
    @player.update(build_args(mouse_click: true, right: true))
    assert_equal :east, @player.swing_dir

    other = Player.new
    other.update(build_args(mouse_click: true, left: true))
    assert_equal :west, other.swing_dir
  end

  def test_swing_direction_follows_movement_without_swinging
    @player.update(build_args(left: true))
    assert_equal :west, @player.swing_dir
    @player.update(build_args(right: true))
    assert_equal :east, @player.swing_dir
  end

  def test_idle_swing_keeps_the_last_swing_direction
    @player.update(build_args(mouse_click: true, left: true)) # swing west
    assert_equal :west, @player.swing_dir
    Player::SWING_TICKS.times { @player.update(build_args) } # let it finish; now idle
    @player.update(build_args(mouse_click: true)) # idle (south) when clicking
    assert_equal :west, @player.swing_dir
  end

  def test_swing_counts_down_each_tick
    @player.update(build_args(mouse_click: true))
    assert_equal Player::SWING_TICKS, @player.swing_ticks_left
    @player.update(build_args)
    assert_equal Player::SWING_TICKS - 1, @player.swing_ticks_left
  end

  def test_cannot_restart_a_swing_until_the_current_one_finishes
    @player.update(build_args(mouse_click: true))
    @player.update(build_args(mouse_click: true)) # click ignored mid-swing
    assert_equal Player::SWING_TICKS - 1, @player.swing_ticks_left
  end

  # --- frozen states ---

  def test_locked_player_ignores_movement_and_swings
    @player.locked = true
    start_x = @player.x
    @player.update(build_args(right: true, mouse_click: true, mouse_x: 1000))
    assert_equal start_x, @player.x
    assert_equal 0, @player.swing_ticks_left
  end

  def test_game_over_player_ignores_movement_and_swings
    @player.game_over = true
    start_x = @player.x
    @player.update(build_args(left: true, mouse_click: true, mouse_x: 1000))
    assert_equal start_x, @player.x
    assert_equal 0, @player.swing_ticks_left
  end

  # --- keyboard hitbox geometry ---

  def test_idle_keyboard_sticks_out_to_the_right_at_hand_height
    @player.swing_dir = :east
    @player.swing_ticks_left = 0
    kb = @player.keyboard_hitbox
    assert_equal @player.x + Player::WIDTH - Player::KEYBOARD_GRIP, kb[:x]
    assert_equal Player::KEYBOARD_W, kb[:w]
    assert_equal Player::KEYBOARD_H, kb[:h]
    assert_equal @player.y + Player::KEYBOARD_HAND_Y, kb[:y]
    assert_operator kb[:x] + kb[:w], :>, @player.x + Player::WIDTH
  end

  def test_idle_keyboard_sticks_out_to_the_left_when_facing_west
    @player.swing_dir = :west
    @player.swing_ticks_left = 0
    kb = @player.keyboard_hitbox
    assert_equal @player.x + Player::KEYBOARD_GRIP - Player::KEYBOARD_W, kb[:x]
    assert_operator kb[:x], :<, @player.x
  end

  def test_swing_thrusts_the_keyboard_farther_out_at_its_apex
    @player.swing_dir = :east
    @player.swing_ticks_left = 0
    held_x = @player.keyboard_hitbox[:x]

    @player.swing_ticks_left = Player::SWING_TICKS / 2 # mid-swing: sin(pi/2) = 1
    apex_x = @player.keyboard_hitbox[:x]
    assert_operator apex_x, :>, held_x
    assert_in_delta held_x + Player::KEYBOARD_SWING_REACH, apex_x, 0.0001
  end

  # --- rendering & serialization ---

  def test_render_emits_the_figure_and_keyboard_as_palette_solids
    args = build_args
    @player.render(args, 0)
    assert_equal 0, args.outputs.sprites.length # no PNG art — the figure is primitives
    # 2 legs + torso card (ink + indigo) + neck + head card (ink + skin) + hair +
    # 2 eyes + keyboard body + keyboard key strip.
    assert_equal 12, args.outputs.solids.length
    # The keyboard's top strip is the light CARD "keys" face.
    keys = args.outputs.solids.last
    assert_equal CARD, [ keys[:r], keys[:g], keys[:b] ]
  end

  def test_serialize_includes_swing_state_and_core_fields
    data = @player.serialize
    assert_equal 0, data[:swing_ticks_left]
    assert_equal :east, data[:swing_dir]
    assert_equal Player::MAX_HEARTS, data[:hearts]
    assert_equal @player.x, data[:x]
    assert_equal false, data[:moved]
    assert_equal false, data[:reached_platform]
  end
end
