class Leaderboard::Query
  AUTHS_COUNT_SQL = %((SELECT COALESCE(SUM("count"), 0) FROM game_stats
    WHERE game_stats.user_id = users.id AND game_stats.key LIKE 'reauth_%') AS auths_count).freeze
  DEFEATS_COUNT_SQL = %((SELECT COALESCE(SUM("count"), 0) FROM game_stats
    WHERE game_stats.user_id = users.id AND game_stats.key LIKE 'defeat_%') AS defeats_count).freeze

  def self.call(by: :level)
    new(by).call
  end

  def initialize(by)
    @by = by.to_s
  end

  def call
    User.left_joins(:earned_achievements)
      .group(:id)
      .select(selections)
      .order(Arel.sql(ordering))
  end

  private

  def selections
    "users.*, COUNT(earned_achievements.id) AS achievements_count, " \
      "MAX(earned_achievements.created_at) AS reached_count_at, " \
      "#{AUTHS_COUNT_SQL}, #{DEFEATS_COUNT_SQL}"
  end

  def ordering
    case @by
    when "achievements" then "achievements_count DESC, reached_count_at ASC, COALESCE(highest_level_completed, -1) DESC"
    when "auths" then "auths_count DESC, COALESCE(highest_level_completed, -1) DESC"
    when "defeats" then "defeats_count DESC, COALESCE(highest_level_completed, -1) DESC"
    else "COALESCE(highest_level_completed, -1) DESC, achievements_count DESC"
    end
  end
end
