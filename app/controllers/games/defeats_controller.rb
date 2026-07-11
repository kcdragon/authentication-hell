class Games::DefeatsController < ApplicationController
  skip_forgery_protection only: :create

  def create
    kind = params[:kind].to_s
    return head :unprocessable_entity unless GameStat::DEFEAT_KINDS.include?(kind)

    GameStat.record(Current.user, "defeat_#{kind}")
    head :no_content
  end
end
