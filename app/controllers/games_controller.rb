class GamesController < ApplicationController
  layout "game"

  # Served path of the static game bundle, namespaced per environment so a dev
  # build (baked for localhost) and a production build (baked for the live
  # domain) never overwrite each other. bin/build-game writes the matching
  # public/<env>_game_assets/ directory.
  helper_method def game_assets_path = "/#{Rails.env}_game_assets/"

  # The DragonRuby game runs WASM with worker threads, which needs
  # SharedArrayBuffer and therefore a cross-origin-isolated page. Set COOP/COEP
  # here for the game page itself; the matching headers for the static bundle
  # are added by GameCrossOriginIsolation middleware.
  before_action :set_cross_origin_isolation_headers, only: :show

  def show
  end

  def me
    render json: { username: Current.user.username }
  end

  private

  def set_cross_origin_isolation_headers
    response.set_header("Cross-Origin-Opener-Policy", "same-origin")
    response.set_header("Cross-Origin-Embedder-Policy", "require-corp")
  end
end
