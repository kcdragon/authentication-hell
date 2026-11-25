require_relative "../local_hot_cell"

HotCell.root = ENV.fetch("HOTCELL_ROOT") { LocalHotCell.root(Rails.root) unless Rails.env.production? }
HotCell.group = ENV["HOTCELL_GROUP"]

HotCell.register "active_storage", timeout: 45

Rails.application.config.after_initialize { HotCell.describe_cells } if Rails.env.production?
