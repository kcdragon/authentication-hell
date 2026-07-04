require_relative "../../test_helper"

class RubyConfLevelTest < Minitest::Test
  include GameTest

  def setup
    @level = RubyConfLevel.new
    @args = build_args(player: Player.new, level: @level)
  end

  def test_number_is_four
    assert_equal 4, @level.number
  end

  def test_presents_as_the_bonus_chapter
    assert_equal "Bonus Chapter", @level.chapter_label
    assert_equal RUBY, @level.accent
  end

  def test_is_the_final_level
    assert_nil @level.next_level
  end

  def test_world_is_the_full_width
    assert_equal WORLD_W, @level.world_w
  end

  def test_setup_scatters_the_full_ruby_count
    @level.setup(@args)
    rubies = @level.collectables.select { |c| c.is_a?(RubyPickup) }
    assert_equal RubyConfLevel::RUBY_COUNT, rubies.length
  end

  def test_ground_rubies_hide_inside_a_grounded_wildflower
    @level.setup(@args)
    ground = @level.collectables.select { |c| c.is_a?(RubyPickup) && c.y == GROUND_Y + RubyPickup::LIFT }

    assert_equal RubyConfLevel::GROUND_RUBY_COUNT, ground.length
    ground.each do |ruby|
      concealed = grounded_plants.any? { |p| ruby.x >= p.x && ruby.x + ruby.w <= p.x + p.w }
      assert concealed, "ruby at #{ruby.x} sits inside a grounded plant's silhouette"
    end
  end

  def test_platform_rubies_perch_on_staircase_tops_behind_a_plant
    @level.setup(@args)
    perch_tops = @level.platforms.select(&:holds_password).map { |p| p.y + p.h }
    perched = @level.collectables.select { |c| c.is_a?(RubyPickup) && perch_tops.include?(c.y) }

    assert_equal RubyConfLevel::PLATFORM_RUBY_COUNT, perched.length
    perched.each do |ruby|
      concealed = @level.plants.any? { |p| p.y == ruby.y && ruby.x >= p.x && ruby.x + ruby.w <= p.x + p.w }
      assert concealed, "ruby at #{ruby.x} sits inside a plant on its platform"
    end
  end

  def test_the_ground_is_a_dense_meadow
    @level.setup(@args)
    assert_operator grounded_plants.length, :>=, 40, "the floor should be thick with wildflowers"
  end

  def test_every_platform_carries_at_least_one_plant
    @level.setup(@args)
    @level.platforms.each do |plat|
      top = plat.y + plat.h
      planted = @level.plants.any? { |p| p.y == top && p.x >= plat.x && p.x + p.w <= plat.x + plat.w }
      assert planted, "platform at #{plat.x} has no plant"
    end
  end

  def test_grounded_plants_never_straddle_a_pit
    @level.setup(@args)
    refute_empty grounded_plants
    grounded_plants.each do |plant|
      overlapping = @level.holes.any? { |hole| plant.x < hole.x + hole.w && plant.x + plant.w > hole.x }
      refute overlapping, "plant at #{plant.x} floats over a pit"
    end
  end

  def test_plants_leave_the_exit_certificate_uncovered
    @level.setup(@args)
    cert_x = @level.world_w - Level::CERTIFICATE_INSET
    covering = @level.plants.select { |p| p.y == GROUND_Y && p.x + p.w > cert_x }
    assert_empty covering, "the exit must stay visible through the meadow"
  end

  def test_setup_starts_with_no_enemies
    @level.setup(@args)
    assert_empty @level.enemies
  end

  def test_waves_spawn_on_an_interval
    @level.setup(@args)
    @level.update(at_tick(0))
    assert_empty @level.enemies

    @level.update(at_tick(WaveSpawner::INTERVAL))
    assert_equal 1, @level.enemies.length
  end

  def test_no_certificate_and_no_completion_while_rubies_remain
    @level.setup(@args)
    @level.update(@args)
    refute(@level.collectables.any? { |c| c.is_a?(Certificate) })
    refute @level.complete?
  end

  def test_spawns_the_certificate_once_when_every_ruby_is_held
    @level.setup(@args)
    collect_all_rubies
    @level.update(@args)
    @level.update(@args)

    assert_equal 1, @level.collectables.count { |c| c.is_a?(Certificate) }
    refute @level.complete?, "not finished until the certificate is picked up"
  end

  def test_completes_when_the_certificate_is_collected
    @level.setup(@args)
    collect_all_rubies
    @level.update(@args)
    @level.collectables.find { |c| c.is_a?(Certificate) }.alive = false
    @level.update(@args)

    assert @level.complete?
  end

  def test_draw_captions_the_ruby_tally
    @level.setup(@args)
    @level.draw(@args)
    assert(@args.outputs.labels.any? { |l| l[:text].include?("#{RubyConfLevel::RUBY_COUNT} rubies") })
  end

  def test_render_world_draws_every_plant
    @level.setup(@args)
    @level.render_world(@args, 0)
    plant_paths = @args.outputs.sprites.map { |s| s[:path] }
    assert_equal @level.plants.length, plant_paths.grep(/plants/).length
  end

  def test_serialize_names_the_level
    assert_equal "RubyConfLevel", @level.serialize[:level]
  end

  private

  def at_tick(tick, camera_x: 0)
    build_args(player: @args.state.player, level: @level, tick_count: tick, camera_x: camera_x)
  end

  def collect_all_rubies
    @level.collectables.each { |c| c.alive = false if c.is_a?(RubyPickup) }
  end

  def grounded_plants
    @level.plants.select { |p| p.y == GROUND_Y }
  end
end
