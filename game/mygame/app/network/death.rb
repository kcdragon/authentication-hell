class Network::Death
  def self.start(args)
    DR.http_post(url(args), {}, [ "Content-Type: application/x-www-form-urlencoded" ])
  end

  def self.url(args) = "#{Network.base_url(args)}/games/death"
end
