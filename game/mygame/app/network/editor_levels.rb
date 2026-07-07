class Network::EditorLevels
  JSON_HEADERS = [ "Content-Type: application/json" ].freeze

  def initialize
    @request = nil
  end

  def fetch_index
    @request = DR.http_get(index_url)
  end

  def fetch_level(slug)
    @request = DR.http_get("#{index_url}/#{slug}")
  end

  def save(json_string)
    @request = DR.http_post_body(index_url, json_string, JSON_HEADERS)
  end

  def promote(slug)
    @request = DR.http_post_body("#{index_url}/#{slug}/promote", "", JSON_HEADERS)
  end

  def pending? = !@request.nil?

  def update
    return unless @request && @request[:complete]

    result = result_of(@request)
    @request = nil
    yield result if block_given?
  end

  private

  def index_url = "#{Network.server_base}/editor/levels"

  def result_of(request)
    if request[:http_response_code] == 200
      { ok: true, data: DR.parse_json(request[:response_data]) }
    else
      { ok: false, code: request[:http_response_code] }
    end
  end
end
