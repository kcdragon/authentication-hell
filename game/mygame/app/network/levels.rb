class Network::Levels
  HEADERS = [ "Content-Type: application/x-www-form-urlencoded" ].freeze

  # The level goes in the query string, not the body: DR.http_post sends a Hash body as
  # multipart, which Rails won't parse under our urlencoded header, so params[:level]
  # would arrive empty (→ 0).
  def self.complete(args, level)
    DR.http_post("#{complete_url(args)}?level=#{level}", {}, HEADERS)
  end

  def self.playing(args, level)
    DR.http_post("#{playing_url(args)}?level=#{level}", {}, HEADERS)
  end

  def self.complete_url(args) = "#{Network.base_url(args)}/games/levels/complete"
  def self.playing_url(args) = "#{Network.base_url(args)}/games/levels/playing"
end
