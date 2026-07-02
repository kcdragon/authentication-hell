# The catalog of every achievement a player can unlock. Plain value objects (not
# ActiveRecord) — which ones a user has earned lives in EarnedAchievement, keyed
# by `key`. Grants come from a few places: clearing a collision re-auth challenge,
# completing a level, or — for the EVENTS below — playing while the clock falls
# inside a fixed `window` (see GamesController#start).
class Achievement
  attr_reader :key, :name, :description, :emoji, :window

  def initialize(key:, name:, description:, emoji:, window: nil)
    @key = key
    @name = name
    @description = description
    @emoji = emoji
    @window = window
  end

  def active_at?(time)
    window&.cover?(time)
  end

  SURVIVOR = [
    new(key: "password_survivor", name: "Password Survivor", emoji: "🔑",
      description: "Survive a collision by entering your password."),
    new(key: "totp_survivor", name: "Code Cracker", emoji: "🔢",
      description: "Survive a collision with a valid authenticator code."),
    new(key: "passkey_survivor", name: "Key Master", emoji: "🛡️",
      description: "Survive a collision with your passkey.")
  ].freeze

  COMPLETION = [
    new(key: "graduate", name: "Certified", emoji: "📜",
      description: "Beat Authentication Hell and claim your certificate."),
    new(key: "social_sharer", name: "Influencer", emoji: "📣",
      description: "Share your certificate with the world.")
  ].freeze

  PACIFIC = ActiveSupport::TimeZone["America/Los_Angeles"]

  EVENTS = [
    new(key: "beta_tester", name: "Beta Tester", emoji: "🧪",
      description: "Play the game before RubyConf.",
      window: ...PACIFIC.parse("2026-07-14 00:00:00")),
    new(key: "rubyconf_attendee", name: "RubyConf Attendee", emoji: "💎",
      description: "Play the game during RubyConf.",
      window: PACIFIC.parse("2026-07-14 00:00:00")..PACIFIC.parse("2026-07-16 23:59:59")),
    new(key: "rubyconf_talk", name: "Live Demo", emoji: "🎤",
      description: "Play the game during the RubyConf talk.",
      window: PACIFIC.parse("2026-07-16 11:15:00")..PACIFIC.parse("2026-07-16 11:45:00"))
  ].freeze

  ALL = (SURVIVOR + COMPLETION + EVENTS + GameLevel.all.map(&:achievement)).freeze

  def self.all
    ALL
  end

  def self.keys
    ALL.map(&:key)
  end

  def self.find(key)
    ALL.find { |achievement| achievement.key == key.to_s }
  end

  def self.active_at(time)
    ALL.select { |achievement| achievement.active_at?(time) }
  end
end
