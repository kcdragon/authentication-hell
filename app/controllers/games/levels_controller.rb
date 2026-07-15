class Games::LevelsController < ApplicationController
  include NowPlaying

  # WASM can't send a CSRF token.
  skip_forgery_protection only: %i[ complete playing ]

  def complete
    level = GameLevel.find(params[:level].to_i)
    return head(:no_content) unless level

    Current.user.record_level_completed(level.number)
    record_best_time(level)
    Achievement::Awarder.call(Current.user, level.achievement_key) if level.awards_achievement?
    advance_now_playing_past(level)
    head :no_content
  end

  def playing
    level = GameLevel.find(params[:level].to_i)
    return head(:no_content) unless level

    mark_now_playing(level)
    clear_permanent_toasts
    head :no_content
  end

  private

  def record_best_time(level)
    ms = params[:ms].to_s
    return unless ms.match?(/\A\d+\z/)

    best_ms = LevelCompletion.record(Current.user, level.number, ms.to_i)
    Game::BestTimeBroadcaster.call(Current.user, level, best_ms) if best_ms
  end

  def advance_now_playing_past(level)
    if (next_level = GameLevel.find(level.number + 1))
      mark_now_playing(next_level)
    else
      Game::PlaylistBroadcaster.call(Current.user)
    end
    beat_game if level == GameLevel.graduation
  end

  def beat_game
    Achievement::Awarder.call(Current.user, :graduate)
    Current.user.mark_certified!
    GenerateCertificatePdfJob.perform_later(Current.user, public_certificate_url(Current.user.ensure_certificate_token!))
    Game::PlaylistBroadcaster.call(Current.user)
    Game::CompletionBroadcaster.call(Current.user)
  end
end
