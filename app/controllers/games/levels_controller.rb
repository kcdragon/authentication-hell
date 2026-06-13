class Games::LevelsController < ApplicationController
  # WASM can't send a CSRF token.
  skip_forgery_protection only: :complete

  def complete
    level = GameLevel.find(params[:level].to_i)
    return head(:no_content) unless level

    Current.user.record_level_completed(level.number)
    Achievement::Awarder.call(Current.user, level.achievement_key)
    head :no_content
  end
end
