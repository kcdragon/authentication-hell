module Network
  def self.base_url(args)
    $server_base ||= (args.gtk.read_file("app/server_config.txt") || "http://localhost:3000").strip
  end

  def self.server_base = $server_base

  def self.death_url(args) = "#{base_url(args)}/games/death"

  def self.challenge_start_url(args, kind) = "#{base_url(args)}/games/#{kind}/start"

  def self.challenge_status_url(args, kind) = "#{base_url(args)}/games/#{kind}/status"
end
