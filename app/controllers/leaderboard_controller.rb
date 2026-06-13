class LeaderboardController < ApplicationController
  SORTS = %w[ level achievements ].freeze

  def index
    @sort = SORTS.include?(params[:sort]) ? params[:sort] : "level"
    @users = User.ranked(by: @sort)
  end
end
