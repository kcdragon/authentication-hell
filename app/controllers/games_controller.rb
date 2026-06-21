class GamesController < ApplicationController
  include NowPlaying

  layout "game_page"

  # Served path of the static game bundle, namespaced per environment so a dev
  # build (baked for localhost) and a production build (baked for the live
  # domain) never overwrite each other, then by a content digest so each build
  # is served under a fresh, immutable URL — busting stale browser/CDN caches on
  # deploy. bin/build-game writes public/<env>_game_assets/<digest>/.
  helper_method def game_assets_path = "/#{Rails.env}_game_assets/#{game_assets_version}/"

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

  def start
    number = session.delete(:selected_level) || Current.user.current_level&.number || 0
    level = GameLevel.find(number)
    mark_now_playing(level) if level
    render json: { start_level: number }
  end

  private

  # The single content-digest subdir bin/build-game leaves under the bundle root.
  # Not memoized in development since bin/watch-game rebuilds (new digest) under a
  # running server; cached elsewhere because the dir is immutable within a deploy.
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
