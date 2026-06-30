# Source of truth for the game's levels. Each level's completion grants a matching
# achievement (generated into Achievement::ALL). Adding a level is one entry here.
class GameLevel
  attr_reader :number, :name, :emoji, :achievement_description

  def initialize(number:, name:, emoji:, achievement_description:)
    @number = number
    @name = name
    @emoji = emoji
    @achievement_description = achievement_description
  end

  ALL = [
    new(number: 0, name: "Welcome", emoji: "🎓",
      achievement_description: "Finish the Welcome level and step into the world."),
    new(number: 1, name: "Password Complexity", emoji: "🔑",
      achievement_description: "Collect two of every character class and forge a password."),
    new(number: 2, name: "Time-Based One-Time Passwords", emoji: "⏱️",
      achievement_description: "Link a temporary authenticator and enter three codes in a row."),
    new(number: 3, name: "The Open World", emoji: "🌅",
      achievement_description: "Clear the main level."),
    new(number: 4, name: "The Gauntlet", emoji: "🏃",
      achievement_description: "Cross the gauntlet without touching the floor.")
  ].freeze

  def achievement_key = "level_#{number}_complete"

  def achievement
    Achievement.new(key: achievement_key, name: "#{name} Cleared",
      emoji: emoji, description: achievement_description)
  end

  def self.all = ALL

  def self.find(number) = ALL.find { it.number == number }
end
