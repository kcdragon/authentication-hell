module Network
  def self.server_base = $server_base

  def self.death_url = "#{server_base}/games/death"

  def self.challenge_start_url(kind) = "#{server_base}/games/#{kind}/start"

  def self.challenge_status_url(kind) = "#{server_base}/games/#{kind}/status"
end
