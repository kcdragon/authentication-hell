class Network::LevelTotp
  FORM_HEADERS = [ "Content-Type: application/x-www-form-urlencoded" ].freeze

  def self.url(args, action) = "#{Network.base_url(args)}/games/level_totp/#{action}"

  def self.poll(args)
    lt = args.state.level_totp
    return unless lt && lt[:active]

    unless lt[:started]
      args.state.level_totp_start_request = DR.http_post(url(args, "start"), {}, FORM_HEADERS)
      lt[:started] = true
    end

    # Code in the query string, not the body: DR.http_post sends a Hash body as
    # multipart, which Rails won't parse under our urlencoded header.
    if lt[:pending_code] && !args.state.level_totp_submit_request
      args.state.level_totp_submit_request =
        DR.http_post("#{url(args, "submit")}?code=#{lt[:pending_code]}", {}, FORM_HEADERS)
      lt[:pending_code] = nil
    end
    if args.state.level_totp_submit_request && args.state.level_totp_submit_request[:complete]
      maybe_complete(args, args.state.level_totp_submit_request)
      lt[:submitting] = false
      args.state.level_totp_submit_request = nil
    end

    if !args.state.level_totp_status_request
      if args.state.tick_count >= (args.state.level_totp_next_poll || 0)
        args.state.level_totp_status_request = DR.http_get(url(args, "status"))
      end
    elsif args.state.level_totp_status_request[:complete]
      maybe_complete(args, args.state.level_totp_status_request)
      args.state.level_totp_status_request = nil
      args.state.level_totp_next_poll = args.state.tick_count + 30
    end
  end

  def self.maybe_complete(args, request)
    return unless request[:http_response_code] == 200

    data = DR.parse_json(request[:response_data])
    return unless data

    lt = args.state.level_totp
    lt[:registered] = data["registered"] if data.key?("registered")
    lt[:streak] = data["streak"] if data.key?("streak")
    lt[:complete] = data["complete"] if data.key?("complete")
    lt[:codes] = data["codes"] if data.key?("codes")
  end
end
