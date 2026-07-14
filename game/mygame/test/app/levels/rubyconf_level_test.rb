require_relative "../../test_helper"

class RubyConfLevelTest < Minitest::Test
  include GameTest

  def setup
    @level = RubyConfLevel.new(build_game)
    @player = Player.new
    @frame = build_frame(player: @player, level: @level)
  end

  def test_number_is_four
    assert_equal 4, @level.number
  end

  def test_presents_as_the_bonus_chapter
    assert_equal "Bonus Chapter", @level.chapter_label
    assert_equal RUBY, @level.accent
  end

  def test_is_the_final_level_without_promoted_levels
    assert_nil @level.next_level
  end

  def test_chains_into_the_first_promoted_level_when_present
    game = build_game(extra_levels: { 5 => { "slug" => "level-9", "title" => "Level 9" } })
    level = RubyConfLevel.new(game)
    following = level.next_level
    assert_instance_of JsonLevel, following
    assert_equal 5, following.number
  end

  def test_world_is_the_full_width
    assert_equal WORLD_W, @level.world_w
  end

  def test_setup_scatters_the_full_ruby_count
    @level.setup(@frame)
    rubies = @level.collectables.select { |c| c.is_a?(RubyPickup) }
    assert_equal RubyConfLevel::RUBY_COUNT, rubies.length
  end

  def test_ground_rubies_hide_inside_a_grounded_wildflower
    @level.setup(@frame)
    ground = @level.collectables.select { |c| c.is_a?(RubyPickup) && c.y == GROUND_Y + RubyPickup::LIFT }

    assert_equal RubyConfLevel::GROUND_RUBY_COUNT, ground.length
    ground.each do |ruby|
      concealed = grounded_plants.any? { |p| ruby.x >= p.x && ruby.x + ruby.w <= p.x + p.w }
      assert concealed, "ruby at #{ruby.x} sits inside a grounded plant's silhouette"
    end
  end

  def test_platform_rubies_perch_on_staircase_tops_behind_a_plant
    @level.setup(@frame)
    perch_tops = @level.platforms.select(&:holds_password).map { |p| p.y + p.h }
    perched = @level.collectables.select { |c| c.is_a?(RubyPickup) && perch_tops.include?(c.y) }

    assert_equal RubyConfLevel::PLATFORM_RUBY_COUNT, perched.length
    perched.each do |ruby|
      concealed = @level.plants.any? { |p| p.y == ruby.y && ruby.x >= p.x && ruby.x + ruby.w <= p.x + p.w }
      assert concealed, "ruby at #{ruby.x} sits inside a plant on its platform"
    end
  end

  def test_the_ground_is_a_dense_meadow
    @level.setup(@frame)
    assert_operator grounded_plants.length, :>=, 40, "the floor should be thick with wildflowers"
  end

  def test_every_platform_carries_at_least_one_plant
    @level.setup(@frame)
    @level.platforms.each do |plat|
      top = plat.y + plat.h
      planted = @level.plants.any? { |p| p.y == top && p.x >= plat.x && p.x + p.w <= plat.x + plat.w }
      assert planted, "platform at #{plat.x} has no plant"
    end
  end

  def test_grounded_plants_never_straddle_a_pit
    @level.setup(@frame)
    refute_empty grounded_plants
    grounded_plants.each do |plant|
      overlapping = @level.holes.any? { |hole| plant.x < hole.x + hole.w && plant.x + plant.w > hole.x }
      refute overlapping, "plant at #{plant.x} floats over a pit"
    end
  end

  def test_plants_leave_the_exit_certificate_uncovered
    @level.setup(@frame)
    cert_x = @level.world_w - Level::CERTIFICATE_INSET
    covering = @level.plants.select { |p| p.y == GROUND_Y && p.x + p.w > cert_x }
    assert_empty covering, "the exit must stay visible through the meadow"
  end

  def test_setup_posts_guards_only_on_ruby_perches
    @level.setup(@frame)
    perch_tops = @level.send(:ruby_perches).map { |p| p.y + p.h }

    refute_empty @level.enemies
    @level.enemies.each do |enemy|
      assert_operator enemy.y, :>, GROUND_Y, "guards start on platforms, not the floor"
      assert_includes perch_tops, enemy.y, "guard at #{enemy.x} stands on a ruby perch"
    end
  end

  def test_guards_patrol_within_their_perch
    @level.setup(@frame)
    @level.enemies.each do |enemy|
      perch = @level.send(:ruby_perches).find { |p| p.y + p.h == enemy.y && enemy.x >= p.x && enemy.x + enemy.w <= p.x + p.w }
      assert perch, "guard at #{enemy.x} stands on a perch"
      assert_operator enemy.patrol_min_x, :>=, perch.x
      assert_operator enemy.patrol_max_x, :<=, perch.x + perch.w - enemy.w
    end
  end

  def test_guards_are_stompable_kinds_never_amber_or_buffering
    @level.setup(@frame)
    kinds = @level.enemies.map(&:class).uniq
    refute_empty kinds
    refute_includes kinds, PasswordEnemy
    refute_includes kinds, BufferingEnemy, "waves supply the pressure — perches get stompable guards"
  end

  def test_waves_spawn_on_an_interval_above_the_seeded_guards
    @level.setup(@frame)
    baseline = @level.enemies.length
    @level.update(at_tick(0))
    assert_equal baseline, @level.enemies.length

    @level.update(at_tick(WaveSpawner::INTERVAL))
    assert_equal baseline + 1, @level.enemies.length
  end

  def test_no_certificate_and_no_completion_while_rubies_remain
    @level.setup(@frame)
    @level.update(@frame)
    refute(@level.collectables.any? { |c| c.is_a?(Certificate) })
    refute @level.complete?
  end

  def test_spawns_the_certificate_once_when_every_ruby_is_held
    @level.setup(@frame)
    collect_all_rubies
    @level.update(@frame)
    @level.update(@frame)

    assert_equal 1, @level.collectables.count { |c| c.is_a?(Certificate) }
    refute @level.complete?, "not finished until the certificate is picked up"
  end

  def test_completes_when_the_certificate_is_collected
    @level.setup(@frame)
    collect_all_rubies
    @level.update(@frame)
    @level.collectables.find { |c| c.is_a?(Certificate) }.alive = false
    @level.update(@frame)

    assert @level.complete?
  end

  def test_draw_captions_the_ruby_tally
    @level.setup(@frame)
    @level.draw(@frame)
    assert(@frame.outputs.labels.any? { |l| l[:text].include?("#{RubyConfLevel::RUBY_COUNT} rubies") })
  end

  def test_render_world_draws_every_plant
    @level.setup(@frame)
    @level.render_world(@frame, 0)
    plant_paths = @frame.outputs.sprites.map { |s| s[:path] }
    assert_equal @level.plants.length, plant_paths.grep(/plants/).length
  end


  private

  def at_tick(tick, camera_x: 0)
    build_frame(player: @player, level: @level, tick_count: tick, camera_x: camera_x)
  end

  def collect_all_rubies
    @level.collectables.each { |c| c.alive = false if c.is_a?(RubyPickup) }
  end

  def grounded_plants
    @level.plants.select { |p| p.y == GROUND_Y }
  end
end
