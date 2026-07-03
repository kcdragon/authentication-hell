require "test_helper"

class GameCrossOriginIsolationTest < ActiveSupport::TestCase
  def app_with_headers(existing = {})
    ->(_env) { [ 200, existing.dup, [ "ok" ] ] }
  end

  def call(path, existing = {})
    middleware = GameCrossOriginIsolation.new(app_with_headers(existing))
    _status, headers, _body = middleware.call("PATH_INFO" => path)
    headers
  end

  test "stamps cross-origin isolation and immutable cache headers on the game bundle" do
    headers = call("/#{Rails.env}_game_assets/abc123/dragonruby.wasm")

    assert_equal "same-origin", headers["Cross-Origin-Resource-Policy"]
    assert_equal "require-corp", headers["Cross-Origin-Embedder-Policy"]
    assert_equal "same-origin", headers["Cross-Origin-Opener-Policy"]
    assert_equal "public, max-age=#{1.year.to_i}, immutable", headers["cache-control"]
  end

  test "leaves non-game requests untouched" do
    headers = call("/favicon.ico", "cache-control" => "public, max-age=3600")

    assert_nil headers["Cross-Origin-Resource-Policy"]
    assert_equal "public, max-age=3600", headers["cache-control"]
  end
end
