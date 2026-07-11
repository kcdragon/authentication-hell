module LeaderboardHelper
  TAB_HINTS = {
    "achievements" => "The furthest, most-decorated players. Sort by level or achievements.",
    "auths" => "Who has survived the most in-game re-authentications, by method.",
    "defeats" => "Who has defeated the most enemies, by kind."
  }.freeze

  def leaderboard_hint
    TAB_HINTS[@tab]
  end

  def leaderboard_tab_link(label, key)
    active = @tab == key
    link_to label, leaderboard_path(tab: key),
      class: "border-[3px] border-ink rounded-[3px] px-4 py-1.5 font-bold text-sm uppercase tracking-wide " \
             "#{active ? "bg-ink text-white shadow-brut-sm" : "bg-card text-muted hover:text-ink"}"
  end

  def leaderboard_sort_link(label, key)
    active = @sort == key
    label = "#{label} ▾" if active
    link_to label, leaderboard_path(sort: key),
      class: "hover:text-ink #{active ? "text-ink underline underline-offset-2 decoration-2" : "text-muted"}"
  end
end
