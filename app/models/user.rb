class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  normalizes :username, with: ->(u) { u.strip }

  validates :email_address, presence: true, uniqueness: true
  validates :username,
    presence: true,
    length: { in: 3..20 },
    format: { with: /\A[a-zA-Z0-9_]+\z/, message: "may only contain letters, numbers, and underscores" },
    uniqueness: { case_sensitive: false }

  generates_token_for :email_confirmation, expires_in: 1.day do
    email_address
  end

  def confirmed?
    confirmed_at.present?
  end

  def confirm!
    update_column(:confirmed_at, Time.current) unless confirmed?
  end
end
