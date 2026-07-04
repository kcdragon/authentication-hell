class Network::OneShot
  FORM_HEADERS = [ "Content-Type: application/x-www-form-urlencoded" ].freeze

  def initialize
    @request = nil
  end

  def post(url)
    @request = DR.http_post(url, {}, FORM_HEADERS)
  end

  def pending? = !@request.nil?

  def update
    return unless @request && @request[:complete]

    data = parse(@request)
    @request = nil
    yield data if block_given?
  end

  private

  def parse(request)
    return nil unless request[:http_response_code] == 200

    DR.parse_json(request[:response_data])
  end
end
