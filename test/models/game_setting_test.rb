require "test_helper"

class GameSettingTest < ActiveSupport::TestCase
  test "instance creates a single row seeded with the defaults" do
    assert_difference -> { GameSetting.count }, 1 do
      setting = GameSetting.instance
      assert_equal GameSetting::DEFAULT_HEART_DROP_CHANCE, setting.heart_drop_chance
      assert_equal GameSetting::DEFAULT_REWIND_DROP_CHANCE, setting.rewind_drop_chance
    end

    assert_no_difference -> { GameSetting.count } do
      GameSetting.instance
    end
  end

  test "drop chances must be between 0 and 1" do
    assert GameSetting.new(heart_drop_chance: 0.5, rewind_drop_chance: 0.5).valid?

    refute GameSetting.new(heart_drop_chance: -0.1, rewind_drop_chance: 0.2).valid?
    refute GameSetting.new(heart_drop_chance: 1.5, rewind_drop_chance: 0.0).valid?
    refute GameSetting.new(heart_drop_chance: nil, rewind_drop_chance: 0.2).valid?
  end

  test "enforces a single row" do
    GameSetting.instance

    second = GameSetting.new(heart_drop_chance: 0.1, rewind_drop_chance: 0.1)
    refute second.valid?
    assert_includes second.errors[:base], "there can only be one GameSetting"
  end

  test "combined drop chance cannot exceed 1.0" do
    setting = GameSetting.new(heart_drop_chance: 0.7, rewind_drop_chance: 0.4)

    refute setting.valid?
    assert_includes setting.errors[:base], "combined heart and rewind drop chance can't exceed 1.0"
  end
end
