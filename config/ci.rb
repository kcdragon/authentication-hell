# Run using bin/ci

CI.run do
  step "Setup", "bin/setup --skip-server"

  step "Style: Ruby", "bin/rubocop"
  step "Style: ERB", "bin/herb"

  step "Security: Gem audit", "bin/bundler-audit"
  step "Security: Importmap vulnerability audit", "bin/importmap audit"
  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"
  # Start from a clean, fixture-ready test DB. A prior run's (or a developer's)
  # db:seed:replant can leave rows fixtures don't manage in the shared test DB,
  # which breaks the fixture foreign-key check below — so reset it first rather
  # than depend on every DB-mutating step cleaning up after itself.
  step "Tests: Reset test DB", "env RAILS_ENV=test bin/rails db:test:prepare"
  step "Tests: Rails", "env COVERAGE=1 bin/rails test"
  # COVERAGE_MINIMUM_LINE is the tracked baseline; fails if line coverage drops below it.
  step "Coverage: Line >= 85%", "env COVERAGE_MINIMUM_LINE=85 ruby script/check_coverage.rb"
  # Plain-Ruby unit tests for the DragonRuby game entities (no engine binary needed).
  step "Tests: Game", "bin/test-game"
  # Verify seeds replant cleanly, then restore the test DB. db:seed:replant
  # truncates and re-seeds the *test* DB, leaving rows that fixtures don't manage
  # (e.g. earned_achievements). Left behind, the next run's fixture foreign-key
  # check fails — most visibly under COVERAGE=1, which runs non-parallel against
  # this shared DB. db:test:prepare resets it to a clean, fixture-ready schema so
  # no run can leave the test DB dirty for the next.
  step "Tests: Seeds", "env RAILS_ENV=test bin/rails db:seed:replant && env RAILS_ENV=test bin/rails db:test:prepare"

  # Optional: Run system tests
  # step "Tests: System", "bin/rails test:system"

  # Set a green GitHub commit status to unblock PR merge — `signoff` is the only
  # required check (there is no cloud CI). Requires `gh extension install basecamp/gh-signoff`.
  if success?
    step "Signoff: All systems go. Ready for merge and deploy.", "gh signoff"
  else
    failure "Signoff: CI failed. Do not merge or deploy.", "Fix the issues and try again."
  end
end
