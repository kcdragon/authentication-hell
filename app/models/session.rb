class Session < ApplicationRecord
  belongs_to :user
  has_many :game_challenges, dependent: :delete_all
end
