class GameSetting < ApplicationRecord
  DEFAULT_HEART_DROP_CHANCE = 0.30
  DEFAULT_REWIND_DROP_CHANCE = 0.35

  validates :heart_drop_chance, :rewind_drop_chance,
            presence: true,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
  validate :combined_drop_chance_within_one
  validate :only_one_row, on: :create

  def self.instance
    first || create!(heart_drop_chance: DEFAULT_HEART_DROP_CHANCE,
                     rewind_drop_chance: DEFAULT_REWIND_DROP_CHANCE)
  end

  private

  def combined_drop_chance_within_one
    return if heart_drop_chance.blank? || rewind_drop_chance.blank?
    return if heart_drop_chance + rewind_drop_chance <= 1.0

    errors.add(:base, "combined heart and rewind drop chance can't exceed 1.0")
  end

  def only_one_row
    errors.add(:base, "there can only be one GameSetting") if GameSetting.exists?
  end
end
