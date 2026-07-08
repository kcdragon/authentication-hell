require "test_helper"

class Editor::LevelFileTest < ActiveSupport::TestCase
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

  test "a new level writes as a draft with only known keys" do
    level = Editor::LevelFile.new(valid_data.merge("evil" => "payload"))

    assert level.valid?
    assert level.draft?
    level.write

    written = JSON.parse(File.read(@draft_root.join("level-5.json")))
    assert_equal "level-5", written["slug"]
    assert_not written.key?("evil")
    assert_empty Dir.children(@root)
  end

  test "saving a slug that is already in the game overwrites the published file" do
    Editor::LevelFile.new(valid_data).write
    Editor::LevelFile.find("level-5").promote!

    level = Editor::LevelFile.new(valid_data.merge("title" => "Revised"))
    assert_not level.draft?
    level.write

    assert_equal "Revised", JSON.parse(File.read(@root.join("level-5.json")))["title"]
    assert_empty Dir.children(@draft_root)
  end

  test "promote moves a draft into the game directory" do
    Editor::LevelFile.new(valid_data).write

    level = Editor::LevelFile.find("level-5")
    assert level.draft?
    level.promote!

    assert_not level.draft?
    assert File.file?(@root.join("level-5.json"))
    assert_empty Dir.children(@draft_root)
    assert_not Editor::LevelFile.find("level-5").draft?
  end

  test "promote refuses a level that is already in the game" do
    Editor::LevelFile.new(valid_data).write
    Editor::LevelFile.find("level-5").promote!

    assert_raises(ArgumentError) { Editor::LevelFile.find("level-5").promote! }
  end

  test "write refuses invalid data" do
    level = Editor::LevelFile.new(valid_data.merge("world_w" => 50))

    assert_not level.valid?
    assert_raises(ArgumentError) { level.write }
    assert_empty Dir.children(@root)
    assert_empty Dir.children(@draft_root)
  end

  test "rejects slugs that could escape the levels directory" do
    [ "../evil", "a/b", "LEVEL", "a b", ".", "" ].each do |slug|
      level = Editor::LevelFile.new(valid_data.merge("slug" => slug))
      assert_not level.valid?, "expected #{slug.inspect} to be rejected"
    end
  end

  test "validates format, accent, ranges and markers" do
    {
      "format" => 2,
      "accent" => "chartreuse",
      "world_w" => 100_000,
      "time_limit" => 5,
      "start_x" => -10,
      "certificate_x" => 999_999
    }.each do |key, bad|
      level = Editor::LevelFile.new(valid_data.merge(key => bad))
      assert_not level.valid?, "expected bad #{key} to be rejected"
    end
  end

  test "start_y defaults to the ground when omitted" do
    level = Editor::LevelFile.new(valid_data)
    assert level.valid?
    level.write

    written = JSON.parse(File.read(@draft_root.join("level-5.json")))
    assert_equal Editor::LevelFile::GROUND_Y, written["start_y"]
  end

  test "start_y persists an authored platform top" do
    level = Editor::LevelFile.new(valid_data.merge("start_y" => 250))
    assert level.valid?
    level.write

    assert_equal 250, JSON.parse(File.read(@draft_root.join("level-5.json")))["start_y"]
  end

  test "validates start_y bounds" do
    [ 99, 2161, -30, "250" ].each do |bad_y|
      level = Editor::LevelFile.new(valid_data.merge("start_y" => bad_y))
      assert_not level.valid?, "expected start_y #{bad_y.inspect} to be rejected"
      assert_includes level.errors, "start_y out of range"
    end

    [ 100, 250, 2160 ].each do |good_y|
      level = Editor::LevelFile.new(valid_data.merge("start_y" => good_y))
      assert level.valid?, "expected start_y #{good_y} to be accepted"
    end
  end

  test "validates entity arrays" do
    bad_entries = {
      "platforms" => [ { "x" => 1 } ],
      "holes" => "nope",
      "enemies" => [ { "kind" => "cobol", "x" => 5 } ]
    }
    bad_entries.each do |key, bad|
      level = Editor::LevelFile.new(valid_data.merge(key => bad))
      assert_not level.valid?, "expected bad #{key} to be rejected"
    end
  end

  test "validates platform y bounds" do
    [ 99, 2160, -30 ].each do |bad_y|
      level = Editor::LevelFile.new(valid_data.merge("platforms" => [ { "x" => 360, "y" => bad_y, "w" => 180 } ]))
      assert_not level.valid?, "expected platform y #{bad_y} to be rejected"
      assert_includes level.errors, "platform y out of range"
    end

    [ 100, 690, 1500, 2130 ].each do |good_y|
      level = Editor::LevelFile.new(valid_data.merge("platforms" => [ { "x" => 360, "y" => good_y, "w" => 180 } ]))
      assert level.valid?, "expected platform y #{good_y} to be accepted"
    end
  end

  test "find returns nil for unknown or malformed slugs" do
    assert_nil Editor::LevelFile.find("missing")
    assert_nil Editor::LevelFile.find("../../etc/passwd")
  end

  test "a corrupt level file fails loudly, naming the file" do
    File.write(@draft_root.join("level-7.json"), "not json")

    error = assert_raises(Editor::LevelFile::CorruptFile) { Editor::LevelFile.all }
    assert_includes error.message, "level-7.json"

    assert_raises(Editor::LevelFile::CorruptFile) { Editor::LevelFile.find("level-7") }
  end

  test "a level file holding a non-object fails loudly" do
    File.write(@draft_root.join("level-7.json"), "[1,2,3]")

    error = assert_raises(Editor::LevelFile::CorruptFile) { Editor::LevelFile.all }
    assert_includes error.message, "does not contain a JSON object"
  end

  test "all and next_slug scan both directories" do
    assert_equal "level-5", Editor::LevelFile.next_slug

    Editor::LevelFile.new(valid_data).write
    Editor::LevelFile.new(valid_data.merge("slug" => "level-9")).write
    Editor::LevelFile.find("level-9").promote!

    assert_equal [ [ "level-5", true ], [ "level-9", false ] ],
                 Editor::LevelFile.all.map { |l| [ l.slug, l.draft? ] }
    assert_equal "level-10", Editor::LevelFile.next_slug
    assert_equal "level-5", Editor::LevelFile.find("level-5").slug
  end

  private

  def valid_data
    {
      "format" => 1,
      "slug" => "level-5",
      "title" => "Buffer Overflow",
      "accent" => "purple",
      "world_w" => 6400,
      "start_x" => 200,
      "time_limit" => 120,
      "certificate_x" => 6120,
      "platforms" => [ { "x" => 360, "y" => 220, "w" => 180 } ],
      "holes" => [ { "x" => 900, "w" => 150 } ],
      "enemies" => [ { "kind" => "totp", "x" => 1400 } ]
    }
  end
end
