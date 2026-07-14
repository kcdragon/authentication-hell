require_relative "../../test_helper"

class JsonLevelTest < Minitest::Test
  include GameTest

  DATA = {
    "format" => 1,
    "slug" => "level-5",
    "title" => "Buffer Overflow",
    "accent" => "purple",
    "world_w" => 3200,
    "start_x" => 150,
    "time_limit" => 90,
    "certificate_x" => 3000,
    "platforms" => [ { "x" => 360, "y" => 220, "w" => 180 },
                     { "x" => 900, "y" => 300, "w" => 240 } ],
    "holes" => [ { "x" => 700, "w" => 150 } ],
    "enemies" => [ { "kind" => "totp", "x" => 1400, "y" => GROUND_Y },
                   { "kind" => "buffering", "x" => 2000, "y" => GROUND_Y } ]
  }.freeze

  def setup
    @level = JsonLevel.new(build_game, DATA.dup)
    @frame = build_frame(level: @level)
  end

  def test_meta_comes_from_the_data
    assert_equal "Buffer Overflow", @level.title
    assert_equal PURPLE, @level.accent
    assert_equal 3200, @level.world_w
    assert_equal 150, @level.start_x
    assert_equal 90, @level.time_limit
    assert_equal "Draft", @level.chapter_label
  end

  def test_start_y_defaults_to_the_ground
    assert_equal GROUND_Y, @level.start_y
  end

  def test_start_y_comes_from_the_data
    level = JsonLevel.new(build_game, DATA.merge("start_y" => 250))
    assert_equal 250, level.start_y
  end

  def test_number_is_unknown_to_rails_progression
    assert_equal 99, @level.number
  end

  def test_setup_builds_platforms_at_their_authored_rects
    @level.setup(@frame)
    assert_equal 2, @level.platforms.length
    platform = @level.platforms.first
    assert_equal [ 360, 220, 180, Platform::H ],
                 [ platform.x, platform.y, platform.w, platform.h ]
  end

  def test_setup_builds_holes_and_enemies_by_kind
    @level.setup(@frame)
    assert_equal [ 700 ], @level.holes.map(&:x)
    assert_equal [ TotpEnemy, BufferingEnemy ], @level.enemies.map(&:class)
    assert_equal [ 1400, 2000 ], @level.enemies.map(&:x)
    assert @level.enemies.all? { |e| e.y == GROUND_Y }
  end

  def test_setup_perches_an_enemy_that_sits_on_a_platform
    data = DATA.merge("enemies" => [ { "kind" => "totp", "x" => 400, "y" => 250 } ])
    level = JsonLevel.new(build_game, data)
    level.setup(@frame)

    platform = level.platforms.first
    enemy = level.enemies.first
    assert_equal platform.y + platform.h, enemy.y
    assert_equal platform.x, enemy.patrol_min_x
    assert_equal platform.x + platform.w - enemy.w, enemy.patrol_max_x
  end

  def test_setup_leaves_a_ground_enemy_free_to_roam
    @level.setup(@frame)
    enemy = @level.enemies.first
    assert_equal GROUND_Y, enemy.y
    assert_equal enemy.x - Enemy::PATROL_RANGE, enemy.patrol_min_x
  end

  def test_setup_skips_unknown_enemy_kinds
    data = DATA.merge("enemies" => [ { "kind" => "cobol", "x" => 500, "y" => GROUND_Y },
                                     { "kind" => "totp", "x" => 900, "y" => GROUND_Y } ])
    level = JsonLevel.new(build_game, data)
    level.setup(@frame)
    assert_equal [ TotpEnemy ], level.enemies.map(&:class)
  end

  def test_setup_spawns_the_certificate_at_the_authored_exit
    @level.setup(@frame)
    certs = @level.collectables.select { |c| c.is_a?(Certificate) }
    assert_equal [ 3000 ], certs.map(&:x)
  end

  def test_setup_twice_rebuilds_a_fresh_world
    @level.setup(@frame)
    @level.enemies.first.alive = false
    @level.collectables.first.alive = false
    @level.setup(@frame)
    assert @level.enemies.all?(&:alive)
    assert @level.collectables.all?(&:alive?)
  end

  def test_defaults_fill_missing_meta
    level = JsonLevel.new(build_game, "slug" => "level-7")
    assert_equal "Level 7", level.title
    assert_equal BLUE, level.accent
    assert_equal WORLD_W, level.world_w
    assert_equal JsonLevel::DEFAULT_START_X, level.start_x
    assert_equal LEVEL_TIME_LIMIT, level.time_limit
  end

  def test_default_certificate_sits_inside_the_exit_inset
    level = JsonLevel.new(build_game, "slug" => "level-7")
    level.setup(@frame)
    assert_equal WORLD_W - Level::CERTIFICATE_INSET, level.collectables.first.x
  end

  def test_completes_only_when_the_certificate_is_collected
    @level.setup(@frame)
    refute @level.complete?
    @level.collectables.first.alive = false
    assert @level.complete?
  end

  def test_has_no_next_level
    assert_nil @level.next_level
  end

  def test_play_mode_reports_its_number_and_chapter_label
    level = JsonLevel.new(build_game, DATA.dup, 5)
    assert_equal 5, level.number
    assert_equal "Chapter 6", level.chapter_label
  end

  def test_play_mode_chains_to_the_next_promoted_level
    game = build_game(extra_levels: { 6 => DATA.merge("title" => "Level 6") })
    level = JsonLevel.new(game, DATA.dup, 5)
    following = level.next_level
    assert_instance_of JsonLevel, following
    assert_equal 6, following.number
    assert_equal "Level 6", following.title
  end

  def test_play_mode_tail_has_no_next_level
    level = JsonLevel.new(build_game, DATA.dup, 5)
    assert_nil level.next_level
  end
end
