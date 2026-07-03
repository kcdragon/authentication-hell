# The cross-origin-isolated /game page (COEP require-corp) needs every game-bundle
# subresource to carry Cross-Origin-Resource-Policy, and Chrome additionally blocks
# the WASM runtime's Web Worker scripts ("coep-frame-resource-needs-coep-header")
# unless the worker response itself carries COEP/COOP.
class GameCrossOriginIsolation
  def initialize(app)
    @app = app
    @assets_prefix = "/#{Rails.env}_game_assets/"
  end

  def call(env)
    status, headers, body = @app.call(env)

    if env["PATH_INFO"].to_s.start_with?(@assets_prefix)
      headers["Cross-Origin-Resource-Policy"] = "same-origin"
      headers["Cross-Origin-Embedder-Policy"] = "require-corp"
      headers["Cross-Origin-Opener-Policy"] = "same-origin"
      headers["cache-control"] = "public, max-age=#{1.year.to_i}, immutable"
    end

    [ status, headers, body ]
  end
end
