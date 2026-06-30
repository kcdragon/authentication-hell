class Session < ApplicationRecord
  belongs_to :user
  has_many :game_challenges, dependent: :delete_all
  has_one :temporary_totp_challenge, dependent: :destroy
end
