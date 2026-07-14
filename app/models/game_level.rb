class GameLevel
  attr_reader :number, :name, :emoji, :achievement_description, :slug, :data

  FIRST_PROMOTED_NUMBER = 5
  PROMOTED_EMOJI = "🎬"

  def initialize(number:, name:, emoji:, achievement_description:, bonus: false, slug: nil, data: nil)
    @number = number
    @name = name
    @emoji = emoji
    @achievement_description = achievement_description
    @bonus = bonus
    @slug = slug
    @data = data
  end

  BUILTIN = [
    new(number: 0, name: "Welcome", emoji: "🎓",
      achievement_description: "Finish the Welcome level and step into the world."),
    new(number: 1, name: "Password Complexity", emoji: "🔑",
      achievement_description: "Collect two of every character class and forge a password."),
    new(number: 2, name: "API Keys", emoji: "📡",
      achievement_description: "Mint an API key and extend the bridge with an authenticated request."),
    new(number: 3, name: "Time-Based One-Time Passwords", emoji: "⏱️",
      achievement_description: "Link a temporary authenticator and enter three codes in a row."),
    new(number: 4, name: "RubyConf Field Trip", emoji: "💎", bonus: true,
      achievement_description: "Collect every ruby hidden in the RubyConf wildflowers.")
  ].freeze

  def achievement_key = "level_#{number}_complete"

  def achievement
    Achievement.new(key: achievement_key, name: "#{name} Cleared",
      emoji: emoji, description: achievement_description)
  end

  def bonus? = @bonus

  def awards_achievement? = @data.nil?

  def self.all = BUILTIN + promoted

  def self.promoted
    published = Editor::LevelFile.all.reject(&:draft?).select(&:valid?)
    published.sort_by { |level| [ level.slug.to_s[/\d+/].to_i, level.slug.to_s ] }
      .each_with_index.map do |level, index|
        new(number: FIRST_PROMOTED_NUMBER + index, name: level.title, emoji: PROMOTED_EMOJI,
          achievement_description: "", bonus: true, slug: level.slug, data: level.data)
      end
  rescue Editor::LevelFile::CorruptFile
    []
  end

  def self.find(number) = all.find { it.number == number }

  def self.graduation = BUILTIN.reject(&:bonus?).last
end
