class Network::Levels
  HEADERS = [ "Content-Type: application/x-www-form-urlencoded" ].freeze

  def self.complete(args, level)
    DR.http_post("#{complete_url(args)}?level=#{level}", {}, HEADERS)
  end

  def self.playing(args, level)
    DR.http_post("#{playing_url(args)}?level=#{level}", {}, HEADERS)
  end

  def self.complete_url(args) = "#{Network.base_url(args)}/games/levels/complete"
  def self.playing_url(args) = "#{Network.base_url(args)}/games/levels/playing"
end
