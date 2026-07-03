module Network
  def self.base_url(args)
    $server_base ||= (args.gtk.read_file("app/server_config.txt") || "http://localhost:3000").strip
  end

  def self.server_base = $server_base
end
