require_relative "../../test_helper"

class EditorSessionTest < Minitest::Test
  include GameTest

  def setup
    @document = LevelDocument.new(slug: "level-5", rules: editor_rules)
    @session = EditorSession.new(@document)
  end

  def test_starts_on_the_select_tool_with_nothing_selected
    assert_equal :select, @session.tool
    assert_nil @session.selection
    assert_equal 0, @session.camera_x
  end

  def test_select_tool_ignores_unknown_tools
    @session.select_tool(:eraser)
    assert_equal :select, @session.tool
  end

  def test_switching_tools_clears_the_selection
    @session.select_tool(:platform)
    @session.press(300, 250)
    refute_nil @session.selection
    @session.select_tool(:select)
    assert_nil @session.selection
  end

  def test_platform_tool_places_at_the_click_and_drags_out_width
    @session.select_tool(:platform)
    @session.press(300, 250)
    @session.drag_to(520, 250)
    @session.release(520, 250)

    platform = @document.items.first
    assert_equal :platform, platform[:type]
    assert_equal 300, platform[:x]
    assert_equal 250 - Platform::H, platform[:y]
    assert_equal 220, platform[:w]
  end

  def test_hole_tool_places_and_drags_out_width
    @session.select_tool(:hole)
    @session.press(700, 50)
    @session.drag_to(1000, 50)

    hole = @document.items.first
    assert_equal :hole, hole[:type]
    assert_equal 700, hole[:x]
    assert_equal 300, hole[:w]
  end

  def test_enemy_tools_place_a_centered_enemy
    @session.select_tool(:enemy_passkey)
    @session.press(1432, GROUND_Y + 10)

    enemy = @document.items.first
    assert_equal "passkey", enemy[:kind]
    assert_equal 1400, enemy[:x]
    assert_equal :item, @session.selection[:kind]
  end

  def test_start_and_certificate_tools_set_the_markers
    @session.select_tool(:start)
    @session.press(1000, GROUND_Y)
    assert_in_delta 1000 - Player::WIDTH / 2, @document.start_x, LevelDocument::GRID

    @session.select_tool(:certificate)
    @session.press(3000, GROUND_Y)
    assert_in_delta 3000 - Certificate::SIZE / 2, @document.certificate_x, LevelDocument::GRID
  end

  def test_select_press_on_an_item_starts_a_move_drag
    platform = @document.add_platform(300, 220, 180)
    @session.press(350, 230)
    assert_same platform, @session.selection[:item]

    @session.drag_to(550, 330)
    assert_equal 500, platform[:x]
    assert_equal 320, platform[:y]
  end

  def test_select_press_on_a_platform_edge_resizes_instead_of_moving
    platform = @document.add_platform(300, 220, 180)
    @session.press(480, 230)
    @session.drag_to(600, 230)
    assert_equal 300, platform[:x]
    assert_equal 300, platform[:w]
  end

  def test_select_press_on_empty_space_clears_the_selection
    @document.add_platform(300, 220, 180)
    @session.press(350, 230)
    @session.press(2000, 500)
    assert_nil @session.selection
  end

  def test_dragging_the_start_marker_moves_it
    @session.press(@document.start_x + 10, GROUND_Y + 10)
    assert_equal :start, @session.selection[:kind]
    @session.drag_to(@document.start_x + 210, GROUND_Y + 10)
    assert_equal 400, @document.start_x
  end

  def test_dragging_the_certificate_moves_it
    wx = @document.certificate_x + 10
    @session.press(wx, GROUND_Y + Certificate::LIFT + 10)
    assert_equal :certificate, @session.selection[:kind]
    @session.drag_to(wx - 500, GROUND_Y + Certificate::LIFT + 10)
    assert_equal WORLD_W - Level::CERTIFICATE_INSET - 500, @document.certificate_x
  end

  def test_release_ends_the_drag
    @session.select_tool(:platform)
    @session.press(300, 250)
    assert @session.dragging?
    @session.release(400, 250)
    refute @session.dragging?
    @session.drag_to(900, 250)
    assert_equal LevelDocument::MIN_ITEM_W, @document.items.first[:w]
  end

  def test_delete_selection_removes_items_but_not_markers
    @document.add_platform(300, 220, 180)
    @session.press(350, 230)
    @session.delete_selection
    assert_empty @document.items

    @session.press(@document.start_x + 10, GROUND_Y + 10)
    @session.delete_selection
    assert_equal :start, @session.selection[:kind]
  end

  def test_pan_clamps_to_the_world
    @session.pan(-500)
    assert_equal 0, @session.camera_x
    @session.pan(WORLD_W * 2)
    assert_equal WORLD_W - SCREEN_W, @session.camera_x
  end

  def test_pan_never_scrolls_a_single_screen_world
    @document.adjust_world_w(-WORLD_W)
    @session.pan(500)
    assert_equal 0, @session.camera_x
  end

  def test_jump_to_centers_the_camera
    @session.jump_to(3200)
    assert_equal 3200 - SCREEN_W / 2, @session.camera_x
    @session.jump_to(0)
    assert_equal 0, @session.camera_x
  end
end
