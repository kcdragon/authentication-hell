class EarnedAchievement < ApplicationRecord
  belongs_to :user

  validates :achievement_key,
    presence: true,
    uniqueness: { scope: :user_id },
    inclusion: { in: Achievement.keys, message: "is not a known achievement" }

  def achievement
    Achievement.find(achievement_key)
  end
end
