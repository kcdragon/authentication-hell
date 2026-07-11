class GamesController < ApplicationController
  include NowPlaying

  layout "game_page"

  helper_method def game_assets_path = "/#{Rails.env}_game_assets/#{game_assets_version}/"

  # The game's WASM worker threads need SharedArrayBuffer, which requires a
  # cross-origin-isolated page.
  before_action :set_cross_origin_isolation_headers, only: %i[ show frame ]

  def show
  end

  def frame
    if params[:level].present? && (level = GameLevel.find(params[:level].to_i))
      frontier = Current.user.current_level&.number
      if (frontier && level.number <= frontier) || Rails.env.development?
        session[:selected_level] = level.number
        mark_now_playing(level)
        clear_permanent_toasts
      end
    end
    render layout: "game_frame"
  end

  def start
    number = session.delete(:selected_level) || Current.user.current_level&.number || 0
    level = GameLevel.find(number)
    mark_now_playing(level) if level
    clear_permanent_toasts
    award_active_achievements
    render json: start_payload(number)
  end

  private

  def start_payload(number)
    settings = GameSetting.instance
    payload = { start_level: number, is_editor_enabled: Rails.env.development?,
                heart_drop_chance: settings.heart_drop_chance.to_f,
                rewind_drop_chance: settings.rewind_drop_chance.to_f }
    payload[:editor_constants] = Editor::LevelFile.client_constants if Rails.env.development?
    payload
  end

  def award_active_achievements
    AwardActiveAchievementsJob.perform_later(Current.user, Time.current)
  end

  # Not memoized in development: bin/watch-game rebuilds (new digest) under a running server.
  def game_assets_version
    return @game_assets_version if defined?(@game_assets_version) && !Rails.env.development?

    dir = Rails.root.join("public", "#{Rails.env}_game_assets")
    @game_assets_version = (Dir.children(dir).first if File.directory?(dir))
  end

  def set_cross_origin_isolation_headers
    response.set_header("Cross-Origin-Opener-Policy", "same-origin")
    response.set_header("Cross-Origin-Embedder-Policy", "require-corp")
  end
end
