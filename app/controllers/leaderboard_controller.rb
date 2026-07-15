class LeaderboardController < ApplicationController
  TABS = %w[ achievements auths defeats times ].freeze
  SORTS = %w[ level achievements ].freeze

  def index
    @tab = TABS.include?(params[:tab]) ? params[:tab] : "achievements"
    return render_times if @tab == "times"

    @sort = sort_for_tab
    @users = Leaderboard::Query.call(by: @sort)
    @game_stats = game_stats_by_user
  end

  private

  def render_times
    @level_boards = level_boards
    render :index
  end

  def level_boards
    completions = LevelCompletion.includes(:user).order(:best_ms, :updated_at).group_by(&:level_number)
    GameLevel.all.map { |level| [ level, completions[level.number] || [] ] }
  end

  def sort_for_tab
    return @tab unless @tab == "achievements"

    SORTS.include?(params[:sort]) ? params[:sort] : "level"
  end

  def game_stats_by_user
    return {} if @tab == "achievements"

    GameStat.where(user_id: @users.map(&:id))
      .pluck(:user_id, :key, :count)
      .each_with_object({}) { |(user_id, key, count), stats| (stats[user_id] ||= {})[key] = count }
  end
end
