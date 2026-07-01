module Network
  # The Rails origin, read once from config (default localhost) and cached in a global
  # so the network helpers can build URLs without threading `args` through. Main seeds
  # it on the first tick; #server_base reads it back arg-free.
  def self.base_url(args)
    $server_base ||= (args.gtk.read_file("app/server_config.txt") || "http://localhost:3000").strip
  end

  def self.server_base = $server_base
end
