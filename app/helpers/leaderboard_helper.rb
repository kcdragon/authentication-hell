module LeaderboardHelper
  def leaderboard_sort_link(label, key)
    active = @sort == key
    label = "#{label} ▾" if active
    link_to label, leaderboard_path(sort: key),
      class: "hover:text-ink #{active ? "text-ink underline underline-offset-2 decoration-2" : "text-muted"}"
  end
end
