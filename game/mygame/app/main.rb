require "app/requires.rb"

module Main
  def tick(args)
    $server_base ||= (args.gtk.read_file("app/server_config.txt") || "http://localhost:3000").strip
    $shell ||= Shell.new
    $shell.tick(args)
  end
end
