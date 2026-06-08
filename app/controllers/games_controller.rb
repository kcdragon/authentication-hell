class GamesController < ApplicationController
  layout "game"

  # The DragonRuby game runs WASM with worker threads, which needs
  # SharedArrayBuffer and therefore a cross-origin-isolated page. Set COOP/COEP
  # here for the game page itself; the matching headers for the static bundle
  # under /game/ are added by GameCrossOriginIsolation middleware.
  before_action :set_cross_origin_isolation_headers, only: :show

  # #me is how the game looks up the username. For now it's unauthenticated and
  # returns a hardcoded value — we're verifying the game can fetch JSON from Rails
  # at all before layering auth back on.
  allow_unauthenticated_access only: :me

  def show
  end

  def me
    render json: { username: "kcdragon" }
  end

  private

  def set_cross_origin_isolation_headers
    response.set_header("Cross-Origin-Opener-Policy", "same-origin")
    response.set_header("Cross-Origin-Embedder-Policy", "require-corp")
  end
end
