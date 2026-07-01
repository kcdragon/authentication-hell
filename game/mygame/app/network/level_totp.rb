class Network::LevelTotp
  FORM_HEADERS = [ "Content-Type: application/x-www-form-urlencoded" ].freeze

  def initialize(level)
    @level = level
  end

  def poll(tick)
    lt = @level.totp
    return unless lt && lt[:active]

    unless lt[:started]
      @level.totp_start_request = DR.http_post(url("start"), {}, FORM_HEADERS)
      lt[:started] = true
    end

    # Code in the query string, not the body: DR.http_post sends a Hash body as
    # multipart, which Rails won't parse under our urlencoded header.
    if lt[:pending_code] && !@level.totp_submit_request
      @level.totp_submit_request =
        DR.http_post("#{url("submit")}?code=#{lt[:pending_code]}", {}, FORM_HEADERS)
      lt[:pending_code] = nil
    end
    if @level.totp_submit_request && @level.totp_submit_request[:complete]
      maybe_complete(@level.totp_submit_request)
      lt[:submitting] = false
      @level.totp_submit_request = nil
    end

    if !@level.totp_status_request
      if tick >= (@level.totp_next_poll || 0)
        @level.totp_status_request = DR.http_get(url("status"))
      end
    elsif @level.totp_status_request[:complete]
      maybe_complete(@level.totp_status_request)
      @level.totp_status_request = nil
      @level.totp_next_poll = tick + 30
    end
  end

  private

  def url(action) = "#{Network.server_base}/games/level_totp/#{action}"

  def maybe_complete(request)
    return unless request[:http_response_code] == 200

    data = DR.parse_json(request[:response_data])
    return unless data

    lt = @level.totp
    lt[:registered] = data["registered"] if data.key?("registered")
    lt[:streak] = data["streak"] if data.key?("streak")
    lt[:complete] = data["complete"] if data.key?("complete")
    lt[:codes] = data["codes"] if data.key?("codes")
  end
end
