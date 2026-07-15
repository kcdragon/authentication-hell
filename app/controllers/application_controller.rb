class ApplicationController < ActionController::Base
  include Authentication
  allow_browser versions: :modern

  stale_when_importmap_changes

  private

  # Chrome blocks every hop of a cross-origin <iframe> navigation unless the
  # response drops X-Frame-Options and carries CORP: cross-origin. Dev-only,
  # for the Slidev talk decks (localhost:3030) embedding the game.
  def allow_cross_origin_framing
    response.headers.delete("X-Frame-Options")
    response.headers["Cross-Origin-Resource-Policy"] = "cross-origin"
  end
end
