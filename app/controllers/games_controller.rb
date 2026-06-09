class GamesController < ApplicationController
  layout "game"

  # The DragonRuby game runs WASM with worker threads, which needs
  # SharedArrayBuffer and therefore a cross-origin-isolated page. Set COOP/COEP
  # here for the game page itself; the matching headers for the static bundle
  # under /game/ are added by GameCrossOriginIsolation middleware.
  before_action :set_cross_origin_isolation_headers, only: :show

  # The game posts here from WASM and can't carry a CSRF token. The request is
  # same-origin and still gated by the session cookie (require_authentication),
  # and it only triggers a broadcast — no state is mutated — so skipping forgery
  # protection for this one action is safe.
  skip_forgery_protection only: :collision

  def show
  end

  def me
    render json: { username: Current.user.username }
  end

  # Called by the game when the player collides with the enemy. Render the toast
  # partial and append it to the player's own page over Turbo Streams; the
  # turbo_stream_from on /play picks it up. Scoped to Current.user so the toast
  # only reaches the player who collided.
  def collision
    toast = { id: SecureRandom.uuid, message: "#{Current.user.username} bumped into the enemy!" }
    Turbo::StreamsChannel.broadcast_append_to(
      Current.user, :toasts,
      target: "toasts",
      partial: "games/toast",
      locals: { toast: toast }
    )
    head :no_content
  end

  private

  def set_cross_origin_isolation_headers
    response.set_header("Cross-Origin-Opener-Policy", "same-origin")
    response.set_header("Cross-Origin-Embedder-Policy", "require-corp")
  end
end
