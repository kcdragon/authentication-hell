class GamesController < ApplicationController
  include NowPlaying

  layout "game_page"

  # Served path of the static game bundle, namespaced per environment so a dev
  # build (baked for localhost) and a production build (baked for the live
  # domain) never overwrite each other. bin/build-game writes the matching
  # public/<env>_game_assets/ directory.
  helper_method def game_assets_path = "/#{Rails.env}_game_assets/"

  # The DragonRuby game runs WASM with worker threads, which needs
  # SharedArrayBuffer and therefore a cross-origin-isolated page. Set COOP/COEP
  # here for the game page itself; the matching headers for the static bundle
  # are added by GameCrossOriginIsolation middleware.
  before_action :set_cross_origin_isolation_headers, only: %i[ show frame ]

  def show
  end

  # The bare canvas + DragonRuby loader, with no app chrome, rendered into an
  # <iframe> by show. The engine's HTML5 build fills its document, so giving it a
  # frame whose viewport is exactly 16:9 makes its render fill the frame with no
  # letterbox. Uses the "game_frame" layout (just <base href> + the canvas shell).
  def frame
    if params[:level].present? && (level = GameLevel.find(params[:level].to_i))
      frontier = Current.user.current_level&.number
      if (frontier && level.number <= frontier) || Rails.env.development?
        session[:selected_level] = level.number
        mark_now_playing(level)
      end
    end
    render layout: "game_frame"
  end

  def me
    start = session.delete(:selected_level) || Current.user.current_level&.number || 0
    render json: { username: Current.user.username, start_level: start }
  end

  private

  def set_cross_origin_isolation_headers
    response.set_header("Cross-Origin-Opener-Policy", "same-origin")
    response.set_header("Cross-Origin-Embedder-Policy", "require-corp")
  end
end
