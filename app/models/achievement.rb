# The catalog of every achievement a player can unlock. Plain value objects (not
# ActiveRecord) — which ones a user has earned lives in EarnedAchievement, keyed
# by `key`. Each is granted the first time a player clears the matching collision
# re-auth challenge (see AwardsAchievements).
class Achievement
  attr_reader :key, :name, :description, :emoji

  def initialize(key:, name:, description:, emoji:)
    @key = key
    @name = name
    @description = description
    @emoji = emoji
  end

  SURVIVOR = [
    new(key: "password_survivor", name: "Password Survivor", emoji: "🔑",
      description: "Survive a collision by entering your password."),
    new(key: "totp_survivor", name: "Code Cracker", emoji: "🔢",
      description: "Survive a collision with a valid authenticator code."),
    new(key: "passkey_survivor", name: "Key Master", emoji: "🛡️",
      description: "Survive a collision with your passkey.")
  ].freeze

  ALL = (SURVIVOR + GameLevel.all.map(&:achievement)).freeze

  def self.all
    ALL
  end

  def self.keys
    ALL.map(&:key)
  end

  def self.find(key)
    ALL.find { |achievement| achievement.key == key.to_s }
  end
end
