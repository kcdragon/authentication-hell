class LeaderboardController < ApplicationController
  TABS = %w[ achievements auths defeats ].freeze
  SORTS = %w[ level achievements ].freeze

  def index
    @tab = TABS.include?(params[:tab]) ? params[:tab] : "achievements"
    @sort = sort_for_tab
    @users = Leaderboard::Query.call(by: @sort)
    @game_stats = game_stats_by_user
  end

  private

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
