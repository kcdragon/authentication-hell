class Network::Poller
  def initialize(url, interval: 30)
    @url = url
    @interval = interval
    @request = nil
    @next_poll = 0
  end

  def poll(tick)
    if !@request
      @request = DR.http_get(@url) if tick >= @next_poll
    elsif @request[:complete]
      if @request[:http_response_code] == 200
        data = DR.parse_json(@request[:response_data])
        yield data if data
      end
      @request = nil
      @next_poll = tick + @interval
    end
  end
end
