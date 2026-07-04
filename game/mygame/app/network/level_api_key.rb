class Network::LevelApiKey
  FORM_HEADERS = [ "Content-Type: application/x-www-form-urlencoded" ].freeze
  POLL_INTERVAL = 30

  def initialize(level)
    @level = level
  end

  def poll(tick)
    api = @level.api
    return unless api && api[:active]

    unless api[:started]
      @level.api_start_request = DR.http_post(url("start"), {}, FORM_HEADERS)
      api[:started] = true
    end
    clear_start_request

    if !@level.api_status_request
      if tick >= (@level.api_next_poll || 0)
        @level.api_status_request = DR.http_get(url("status"))
      end
    elsif @level.api_status_request[:complete]
      read_status(@level.api_status_request)
      @level.api_status_request = nil
      @level.api_next_poll = tick + POLL_INTERVAL
    end
  end

  private

  def url(action) = "#{Network.server_base}/games/level_api_key/#{action}"

  def clear_start_request
    request = @level.api_start_request
    @level.api_start_request = nil if request && request[:complete]
  end

  def read_status(request)
    return unless request[:http_response_code] == 200

    data = DR.parse_json(request[:response_data])
    return unless data

    @level.api[:opened] = data["opened"] if data.key?("opened")
  end
end
