class Network::Death
  def self.start(args)
    args.state.death_request = DR.http_post(url(args), {}, [ "Content-Type: application/x-www-form-urlencoded" ])
  end

  def self.maybe_complete(state)
    state.death_request = nil if state.death_request && state.death_request[:complete]
  end

  def self.url(args) = "#{Network.base_url(args)}/games/death"
end
