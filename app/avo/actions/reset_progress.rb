class Avo::Actions::ResetProgress < Avo::BaseAction
  self.name = "Reset progress"
  self.message = "Reset this user's level progress, leaderboard standing, and achievements? This can't be undone."
  self.confirm_button_label = "Reset progress"

  def handle(query:, **args)
    query.each(&:reset_progress!)
    succeed "Progress reset for #{query.size} user(s)."
  end
end
