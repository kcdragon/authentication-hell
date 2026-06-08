class GamesController < ApplicationController
  layout "game"

  # The DragonRuby game runs WASM with worker threads, which needs
  # SharedArrayBuffer and therefore a cross-origin-isolated page. Set COOP/COEP
  # here for the game page itself; the matching headers for the static bundle
  # under /game/ are added by GameCrossOriginIsolation middleware.
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
