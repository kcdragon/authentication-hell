require_relative "../../test_helper"

class LevelDocumentTest < Minitest::Test
  include GameTest

  def setup
    @document = LevelDocument.new(slug: "level-5", rules: editor_rules)
  end

  def test_defaults
    assert_equal "Level 5", @document.title
    assert_equal "blue", @document.accent
    assert_equal WORLD_W, @document.world_w
    assert_equal JsonLevel::DEFAULT_START_X, @document.start_x
    assert_equal LEVEL_TIME_LIMIT, @document.time_limit
    assert_equal WORLD_W - Level::CERTIFICATE_INSET, @document.certificate_x
    assert_empty @document.items
  end

  def test_snap_rounds_to_the_grid
    item = @document.add_platform(304, 217, 183)
    assert_equal 300, item[:x]
    assert_equal 220, item[:y]
    assert_equal 180, item[:w]

    item = @document.add_platform(305, 215, 185)
    assert_equal 310, item[:x]
    assert_equal 220, item[:y]
    assert_equal 190, item[:w]
  end

  def test_platform_width_has_a_floor
    item = @document.add_platform(300, 220, 10)
    assert_equal LevelDocument::MIN_ITEM_W, item[:w]
  end

  def test_platforms_stay_inside_the_world_and_above_the_ground
    item = @document.add_platform(-40, 50, 100)
    assert_equal 0, item[:x]
    assert_equal GROUND_Y, item[:y]

    item = @document.add_platform(WORLD_W + 500, SCREEN_H + 100, 100)
    assert_equal WORLD_W - item[:w], item[:x]
    assert_equal SCREEN_H - Platform::H, item[:y]
  end

  def test_add_enemy_rejects_unknown_kinds
    assert_nil @document.add_enemy("cobol", 500)
    assert_empty @document.items
  end

  def test_move_to_snaps_and_keeps_holes_on_the_ground
    hole = @document.add_hole(700, 150)
    @document.move_to(hole, 913, 400)
    assert_equal 910, hole[:x]
    refute hole.key?(:y)
  end

  def test_resize_only_applies_to_platforms_and_holes
    enemy = @document.add_enemy("totp", 500)
    @document.resize(enemy, 300)
    refute enemy.key?(:w)
  end

  def test_delete_removes_the_item
    item = @document.add_hole(700, 150)
    @document.delete(item)
    assert_empty @document.items
  end

  def test_start_and_certificate_clamp_into_the_world
    @document.set_start_x(-50)
    assert_equal 0, @document.start_x
    @document.set_certificate_x(WORLD_W * 2)
    assert_equal WORLD_W - Certificate::SIZE, @document.certificate_x
  end

  def test_cycle_accent_walks_the_palette_and_wraps
    names = []
    editor_rules["accents"].length.times do
      @document.cycle_accent
      names << @document.accent
    end
    assert_equal editor_rules["accents"].rotate(1), names
    assert_equal "blue", names.last
  end

  def test_adjust_world_w_clamps_and_reins_in_markers
    @document.adjust_world_w(-WORLD_W * 2)
    assert_equal editor_rules["world_w_min"], @document.world_w
    assert_operator @document.certificate_x, :<=, @document.world_w - Certificate::SIZE

    @document.adjust_world_w(WORLD_W * 10)
    assert_equal editor_rules["world_w_max"], @document.world_w
  end

  def test_adjust_time_limit_clamps
    @document.adjust_time_limit(-1000)
    assert_equal editor_rules["time_limit_min"], @document.time_limit
    @document.adjust_time_limit(10_000)
    assert_equal editor_rules["time_limit_max"], @document.time_limit
  end

  def test_item_at_prefers_the_most_recently_added
    first = @document.add_platform(300, 220, 180)
    second = @document.add_platform(300, 220, 180)
    assert_same second, @document.item_at(310, 230)
    @document.delete(second)
    assert_same first, @document.item_at(310, 230)
  end

  def test_item_at_hits_enemies_and_holes_by_their_rects
    enemy = @document.add_enemy("totp", 500)
    hole = @document.add_hole(700, 150)
    assert_same enemy, @document.item_at(510, GROUND_Y + 50)
    assert_same hole, @document.item_at(710, 50)
    assert_nil @document.item_at(4000, 500)
  end

  def test_platform_edge_at_grabs_the_right_edge_only
    platform = @document.add_platform(300, 220, 180)
    assert_same platform, @document.platform_edge_at(480, 230)
    assert_same platform, @document.platform_edge_at(480 + LevelDocument::EDGE_GRAB, 230)
    assert_nil @document.platform_edge_at(400, 230)
  end

  def test_start_and_certificate_hit_boxes
    assert @document.start_hit?(@document.start_x + 10, GROUND_Y + 10)
    refute @document.start_hit?(@document.start_x + 10, GROUND_Y + Player::HEIGHT + 50)
    assert @document.certificate_hit?(@document.certificate_x + 10, GROUND_Y + Certificate::LIFT + 10)
  end

  def test_blank_title_falls_back_to_the_humanized_slug
    @document.title = "Chasm Run"
    assert_equal "Chasm Run", @document.title
    @document.title = ""
    assert_equal "Level 5", @document.title
  end

  def test_round_trips_through_hash_and_json
    @document.add_platform(360, 220, 180)
    @document.add_hole(900, 150)
    @document.add_enemy("passkey", 1400)
    @document.title = "Chasm \"Run\""
    @document.cycle_accent

    parsed = JSON.parse(@document.to_json_string)
    assert_equal @document.to_h, parsed
    assert_equal @document.to_h, LevelDocument.from_h(parsed, editor_rules).to_h
  end

  def test_level_data_feeds_json_level_directly
    @document.add_platform(360, 220, 180)
    assert_equal 1, @document.level_data["platforms"].length
    assert_equal 1, @document.level_data["format"]
  end
end
