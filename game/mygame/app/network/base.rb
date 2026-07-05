module Network
  def self.base_url(args)
    $server_base ||= (args.gtk.read_file("app/server_config.txt") || "http://localhost:3000").strip
  end

  def self.server_base = $server_base

  def self.death_url = "#{server_base}/games/death"

  def self.challenge_start_url(kind) = "#{server_base}/games/#{kind}/start"

  def self.challenge_status_url(kind) = "#{server_base}/games/#{kind}/status"
end
