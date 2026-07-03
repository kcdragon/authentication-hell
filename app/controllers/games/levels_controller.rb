class Games::LevelsController < ApplicationController
  include NowPlaying

  # WASM can't send a CSRF token.
  skip_forgery_protection only: %i[ complete playing ]

  def complete
    level = GameLevel.find(params[:level].to_i)
    return head(:no_content) unless level

    Current.user.record_level_completed(level.number)
    Achievement::Awarder.call(Current.user, level.achievement_key)
    advance_now_playing_past(level)
    head :no_content
  end

  def playing
    level = GameLevel.find(params[:level].to_i)
    return head(:no_content) unless level

    mark_now_playing(level)
    clear_completion_toast_if_beaten
    head :no_content
  end

  private

  def advance_now_playing_past(level)
    next_level = GameLevel.find(level.number + 1)
    if next_level
      mark_now_playing(next_level)
    else
      beat_game
    end
  end

  def beat_game
    Achievement::Awarder.call(Current.user, :graduate)
    Current.user.mark_certified!
    GenerateCertificatePdfJob.perform_later(Current.user, public_certificate_url(Current.user.ensure_certificate_token!))
    Game::PlaylistBroadcaster.call(Current.user)
    Game::CompletionBroadcaster.call(Current.user)
  end
end
