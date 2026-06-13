# The /game page is cross-origin isolated (COOP/COEP set in GamesController) so
# its WASM runtime can use SharedArrayBuffer. Under COEP require-corp, every
# subresource it loads must opt in with Cross-Origin-Resource-Policy, so stamp it
# onto the static game bundle (served under the per-environment path
# /<env>_game_assets/). Scoped to that prefix so the rest of the site is unaffected.
#
# The WASM runtime also spawns pthreads as dedicated Web Workers, loading
# dragonruby-wasm.js as the worker script. Under require-corp a Worker script is
# not covered by CORP alone — Chrome blocks it with
# "coep-frame-resource-needs-coep-header" unless the worker response itself
# carries Cross-Origin-Embedder-Policy. So stamp COEP (and COOP) here too,
# matching what DragonRuby's bundled service worker does for a standalone build.
class GameCrossOriginIsolation
  def initialize(app)
    @app = app
    # Matches GamesController#game_assets_path and the bundle dir bin/build-game writes.
    @assets_prefix = "/#{Rails.env}_game_assets/"
  end

  def call(env)
    status, headers, body = @app.call(env)

    if env["PATH_INFO"].to_s.start_with?(@assets_prefix)
      headers["Cross-Origin-Resource-Policy"] = "same-origin"
      headers["Cross-Origin-Embedder-Policy"] = "require-corp"
      headers["Cross-Origin-Opener-Policy"] = "same-origin"
    end

    [ status, headers, body ]
  end
end
