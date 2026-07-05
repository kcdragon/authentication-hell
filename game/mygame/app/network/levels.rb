class Network::Levels
  HEADERS = [ "Content-Type: application/x-www-form-urlencoded" ].freeze

  def self.complete(level)
    DR.http_post("#{complete_url}?level=#{level}", {}, HEADERS)
  end

  def self.playing(level)
    DR.http_post("#{playing_url}?level=#{level}", {}, HEADERS)
  end

  def self.complete_url = "#{Network.server_base}/games/levels/complete"
  def self.playing_url = "#{Network.server_base}/games/levels/playing"
end
