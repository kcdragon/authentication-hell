require "digest"
require "tmpdir"

module LocalHotCell
  def self.root(app_root)
    checkout_id = Digest::SHA256.hexdigest(app_root.to_s)[0, 12]
    File.join(ENV.fetch("XDG_RUNTIME_DIR") { Dir.tmpdir }, "hotcell-#{checkout_id}")
  end

  def self.socket_dir(app_root)
    File.join(root(app_root), "active_storage")
  end
end
