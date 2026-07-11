class Network::Defeats
  HEADERS = [ "Content-Type: application/x-www-form-urlencoded" ].freeze

  def self.report(kind)
    DR.http_post("#{url}?kind=#{kind}", {}, HEADERS)
  end

  def self.url = "#{Network.server_base}/games/defeats"
end
