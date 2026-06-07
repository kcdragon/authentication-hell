# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Two unrelated things live in one repo:

1. **A Rails 8.1 web application** (root) — generated with `rails new --css tailwind --edge`. Currently a stock scaffold: no domain models, controllers, or routes have been added yet (`app/models` has only `ApplicationRecord`, `config/routes.rb` defines only `/up`). The presumable goal, per the repo name, is authentication.
2. **A bundled copy of DragonRuby GTK** under `game/` — the proprietary game engine binary plus the default "Hello World" sample game in `game/mygame/`. This is committed wholesale and is **not** part of the Rails app. Treat it as a vendored tool, not application code.

These two have no code-level connection. Changes to the Rails app should not touch `game/`, and vice versa.

## Rails app

### Stack
- **Rails 8.1** tracking the `8-1-stable` branch from GitHub (edge — `bundle update rails` pulls new commits).
- **Ruby 4.0.2** (see `.ruby-version`).
- **SQLite** for everything, including production (separate DB files per concern: primary, cache, queue, cable — all under `storage/`).
- **Solid Queue / Solid Cache / Solid Cable** — database-backed adapters, no Redis.
- **Hotwire** (Turbo + Stimulus) with **importmap** (no JS bundler/npm). **Propshaft** asset pipeline. **Tailwind** via `tailwindcss-rails`.
- Deploy via **Kamal** (Docker); `config/deploy.yml` still has placeholder servers/IPs.

### Commands
```bash
bin/setup              # install deps, prepare DB, start server (--skip-server to stop short, --reset to reset DB)
bin/dev                # run web server + Tailwind watcher together (foreman, Procfile.dev), port 3000
bin/rails test         # run all tests (Minitest)
bin/rails test test/models/user_test.rb            # single file
bin/rails test test/models/user_test.rb:42         # single test by line number
bin/rails test:system  # Capybara + Selenium system tests (not run in bin/ci by default)
bin/rubocop            # lint (rubocop-rails-omakase house style)
bin/brakeman           # static security scan
bin/bundler-audit      # gem vulnerability audit
bin/ci                 # run the full CI pipeline locally (config/ci.rb)
```

### CI
`config/ci.rb` (run via `bin/ci`) is the source of truth for what must pass: setup, RuboCop, bundler-audit, importmap audit, Brakeman, `bin/rails test`, and seed replant. `.github/workflows/ci.yml` runs the same checks plus system tests. Run `bin/ci` before pushing to catch what the GitHub workflow will.

### Conventions
- Tailwind compiles to `app/assets/builds/tailwind.css`; `bin/dev` runs `tailwindcss:watch` so edits to `app/assets/tailwind/` rebuild live. Don't hand-edit the built file.
- The three `db/*_schema.rb` files (cable/cache/queue) are the Solid adapters' schemas — not the app schema. There is no `db/schema.rb` yet because no app migrations exist; one appears after the first `bin/rails generate model`.
- For `has_secure_password`, uncomment `bcrypt` in the `Gemfile` first (it ships commented out).

## DragonRuby (`game/`)

- `game/dragonruby` is a Mach-O binary (the engine). Game code lives in `game/mygame/app/main.rb` — the entry point is a `tick` method called every frame. `game/samples/` has 150+ example apps and `game/docs/` has the offline docs.
- Run the game: `cd game && ./dragonruby` (or `./dragonruby mygame`). Hot-reloads `main.rb` on save while running.
- This directory is vendored as-is. Avoid reformatting, linting, or "cleaning up" anything under `game/` — it's upstream engine code and samples, not ours.

## Secrets

Never invent placeholder encryption keys or API tokens. If a real secret is needed, ask Mike to add it to Rails credentials (`bin/rails credentials:edit`) rather than hardcoding a fake value.
