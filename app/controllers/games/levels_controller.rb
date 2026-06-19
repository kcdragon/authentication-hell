class Games::LevelsController < ApplicationController
  include NowPlaying

  # WASM can't send a CSRF token.
  skip_forgery_protection only: %i[ complete playing ]

  def complete
    level = GameLevel.find(params[:level].to_i)
    return head(:no_content) unless level

    Current.user.record_level_completed(level.number)
    Achievement::Awarder.call(Current.user, level.achievement_key)
    Game::PlaylistBroadcaster.call(Current.user)
    head :no_content
  end

  def playing
    level = GameLevel.find(params[:level].to_i)
    return head(:no_content) unless level

    mark_now_playing(level)
    head :no_content
  end
end
