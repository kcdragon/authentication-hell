class WebauthnCredential < ApplicationRecord
  belongs_to :user

  normalizes :nickname, with: ->(n) { n.to_s.strip.presence || "Passkey" }

  validates :external_id, presence: true, uniqueness: true
  validates :public_key, :nickname, presence: true
end
