# The /play page is cross-origin isolated (COOP/COEP set in GamesController) so
# its WASM runtime can use SharedArrayBuffer. Under COEP require-corp, every
# subresource it loads must opt in with Cross-Origin-Resource-Policy, so stamp it
# onto the static game bundle under /game/. Scoped to /game/ so the rest of the
# site is unaffected.
class GameCrossOriginIsolation
  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)

    if env["PATH_INFO"].to_s.start_with?("/game/")
      headers["Cross-Origin-Resource-Policy"] = "same-origin"
    end

    [ status, headers, body ]
  end
end
