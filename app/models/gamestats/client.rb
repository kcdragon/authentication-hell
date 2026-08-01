require "net/http"

module Gamestats::Client
  extend self

  class Error < StandardError; end
  class NotFoundError < Error; end

  HOST = "gamestats.ai".freeze
  UNVERSIONED = "development".freeze

  def configured?
    api_key.present? && account_id.present?
  end

  def achievement_event(player_username:, achievement_name:, occurred_at:, version_name: deployed_version)
    post("/api/v1/accounts/#{account_id}/achievement_events",
      version_name:,
      player_username:,
      achievement_name:,
      occurred_at: occurred_at.iso8601)
  end

  def progression_event(player_username:, progression_type_name:, progression_name:,
    milestone_type_name:, milestone_name:, occurred_at:,
    time_elapsed: nil, is_new_instance: false, version_name: deployed_version)
    body = {
      version_name:,
      player_username:,
      progression_name:,
      progression_type_name:,
      progression_milestone_name: milestone_name,
      progression_milestone_type_name: milestone_type_name,
      occurred_at: occurred_at.iso8601
    }
    body[:is_new_instance] = true if is_new_instance
    body[:time_elapsed] = time_elapsed unless time_elapsed.nil?

    post("/api/v1/accounts/#{account_id}/progression_events", body)
  end

  def rename_player(old_username:, new_username:)
    patch("/api/v1/accounts/#{account_id}/players/rename",
      username: old_username,
      new_username:)
  end

  def upload_achievement_image(achievement_name:, image_path:)
    raise Error, "gamestats.ai is not configured" unless configured?

    uri = URI::HTTPS.build(host: HOST, path: "/api/v1/accounts/#{account_id}/achievement_images")
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{api_key}"

    File.open(image_path, "rb") do |image|
      request.set_form(
        [ [ "achievement_name", achievement_name ],
          [ "image", image, { filename: File.basename(image_path), content_type: "image/png" } ] ],
        "multipart/form-data")

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
      return response if response.is_a?(Net::HTTPSuccess)

      raise Error, "gamestats.ai #{uri.path} returned #{response.code}: #{response.body}"
    end
  end

  private

  def deployed_version
    ENV["KAMAL_VERSION"].presence || UNVERSIONED
  end

  def api_key
    Rails.application.credentials.dig(:gamestats, :api_key)
  end

  def account_id
    Rails.application.credentials.dig(:gamestats, :account_id)
  end

  def post(path, body = nil)
    send_request(Net::HTTP::Post, path, body)
  end

  def patch(path, body = nil)
    send_request(Net::HTTP::Patch, path, body)
  end

  def send_request(request_class, path, body)
    raise Error, "gamestats.ai is not configured" unless configured?

    uri = URI::HTTPS.build(host: HOST, path:)
    request = request_class.new(uri)
    request["Authorization"] = "Bearer #{api_key}"
    request["Content-Type"] = "application/json"
    request.body = body.to_json if body

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    return response if response.is_a?(Net::HTTPSuccess)

    raise NotFoundError, "gamestats.ai #{path} returned 404: #{response.body}" if response.is_a?(Net::HTTPNotFound)
    raise Error, "gamestats.ai #{path} returned #{response.code}: #{response.body}"
  end
end
