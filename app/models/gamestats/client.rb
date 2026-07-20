require "net/http"

module Gamestats::Client
  extend self

  class Error < StandardError; end

  HOST = "gamestats.ai".freeze

  def configured?
    api_key.present? && account_id.present?
  end

  def achievement_event(player_username:, achievement_name:, occurred_at:)
    post("/api/v1/accounts/#{account_id}/achievement_events",
      player_username:,
      achievement_name:,
      occurred_at: occurred_at.iso8601)
  end

  private

  def api_key
    Rails.application.credentials.dig(:gamestats, :api_key)
  end

  def account_id
    Rails.application.credentials.dig(:gamestats, :account_id)
  end

  def post(path, body = nil)
    uri = URI::HTTPS.build(host: HOST, path:)
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{api_key}"
    request["Content-Type"] = "application/json"
    request.body = body.to_json if body

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    unless response.is_a?(Net::HTTPSuccess)
      raise Error, "gamestats.ai #{path} returned #{response.code}: #{response.body}"
    end

    response
  end
end
