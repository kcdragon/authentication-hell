require "test_helper"

class GameLevelTest < ActiveSupport::TestCase
  test "all returns GameLevels" do
    assert GameLevel.all.any?
    assert GameLevel.all.all? { |l| l.is_a?(GameLevel) }
  end

  test "find looks up by number and returns nil for an unknown level" do
    assert_equal "Welcome", GameLevel.find(0).name
    assert_nil GameLevel.find(999)
  end

  test "the levels run welcome, password, api keys, totp, then the rubyconf bonus" do
    assert_equal "Password Complexity", GameLevel.find(1).name
    assert_equal "level_1_complete", GameLevel.find(1).achievement_key
    assert_equal "API Keys", GameLevel.find(2).name
    assert_equal "Time-Based One-Time Passwords", GameLevel.find(3).name
    assert_equal "RubyConf Field Trip", GameLevel.find(4).name
    assert_nil GameLevel.find(5)
  end

  test "only the rubyconf level is a bonus" do
    assert GameLevel.find(4).bonus?
    assert_equal [ 4 ], GameLevel.all.select(&:bonus?).map(&:number)
  end

  test "graduation is the last non-bonus level" do
    assert_equal 3, GameLevel.graduation.number
  end

  test "achievement_key is derived from the level number" do
    assert_equal "level_0_complete", GameLevel.find(0).achievement_key
  end

  test "achievement carries the level's key, name, and emoji" do
    level = GameLevel.find(1)
    achievement = level.achievement

    assert_equal level.achievement_key, achievement.key
    assert_equal "#{level.name} Cleared", achievement.name
    assert_equal level.emoji, achievement.emoji
  end

  test "built-in levels award achievements; promoted ones do not" do
    assert GameLevel.find(1).awards_achievement?
  end

  class PromotedLevels < ActiveSupport::TestCase
    setup do
      @root = Pathname.new(Dir.mktmpdir)
      @draft_root = Pathname.new(Dir.mktmpdir)
      Editor::LevelFile.root = @root
      Editor::LevelFile.draft_root = @draft_root
    end

    teardown do
      Editor::LevelFile.root = Rails.root.join("game/mygame/data/levels")
      Editor::LevelFile.draft_root = Rails.root.join("level_drafts")
      FileUtils.remove_entry(@root)
      FileUtils.remove_entry(@draft_root)
    end

    test "promoted levels become contiguous bonus chapters after the built-ins" do
      promote("level-9", "Level 9")
      promote("level-12", "Twelfth")
      write_draft("level-20", "Still A Draft")

      promoted = GameLevel.promoted
      assert_equal [ 5, 6 ], promoted.map(&:number)
      assert_equal [ "Level 9", "Twelfth" ], promoted.map(&:name)
      assert promoted.all?(&:bonus?)
      assert_not promoted.any?(&:awards_achievement?)
    end

    test "all appends promoted levels and find reaches them" do
      promote("level-9", "Level 9")

      assert_equal [ 0, 1, 2, 3, 4, 5 ], GameLevel.all.map(&:number)
      assert_equal "Level 9", GameLevel.find(5).name
    end

    test "graduation stays at the last built-in non-bonus level" do
      promote("level-9", "Level 9")
      assert_equal 3, GameLevel.graduation.number
    end

    test "promoted carries the level data for the game payload" do
      promote("level-9", "Level 9")
      assert_equal "level-9", GameLevel.find(5).data["slug"]
    end

    private

    def promote(slug, title)
      write_draft(slug, title)
      Editor::LevelFile.find(slug).promote!
    end

    def write_draft(slug, title)
      Editor::LevelFile.new(level_data(slug, title)).write
    end

    def level_data(slug, title)
      {
        "format" => 1, "slug" => slug, "title" => title, "accent" => "blue",
        "world_w" => 6400, "start_x" => 200, "time_limit" => 120, "certificate_x" => 6120,
        "platforms" => [], "holes" => [], "enemies" => []
      }
    end
  end
end
