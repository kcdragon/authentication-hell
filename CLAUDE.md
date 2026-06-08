# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Two things live in one repo:

1. **A Rails 8.1 web application** (root) — generated with `rails new --css tailwind --edge`. No domain/auth models exist yet (`app/models` has only `ApplicationRecord`); the presumable goal, per the repo name, is authentication. The one real feature so far is embedding the DragonRuby game (below) at `/play`.
2. **A bundled copy of DragonRuby GTK** under `game/` — the proprietary game engine binary plus a sample game in `game/mygame/`. The engine and `game/{samples,docs,builds,logs}` are vendored as-is; treat them as a tool, not application code. The game *source* in `game/mygame/` is ours to edit, and the Rails app serves a built copy of it.

**How the two connect:** `bin/build-game` packages `game/mygame/` to an HTML5/WASM bundle and unzips it into `public/game/` (a static, gitignored build artifact). Rails serves it at `/play` via `GamesController`. So the game is no longer standalone — it's a build input to the Rails app. See "DragonRuby game served at /play" below.

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
bin/dev                # web server + Tailwind watcher + game watcher together (foreman, Procfile.dev), port 3000
bin/build-game         # package game/mygame/ to HTML5 and unzip into public/game/ (one-shot)
bin/watch-game         # build-game once, then rebuild on any change under game/mygame/ (run by bin/dev)
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
`config/ci.rb` (run via `bin/ci`) is the source of truth for what must pass: setup, RuboCop, bundler-audit, importmap audit, Brakeman, `bin/rails test`, and seed replant. `.github/workflows/ci.yml` runs the same checks plus system tests.

**Run `bin/ci` after implementing any change** — it's the fastest way to catch what the GitHub workflow will, and it must pass before pushing.

RuboCop and Brakeman are scoped to *our* code only: everything under `game/` is excluded except `game/mygame/`, and within that, only `main.rb` is linted (`repl.rb` is DragonRuby's vendored console scratch file). See `.rubocop.yml` (`AllCops/Exclude`) and `config/brakeman.yml` (`skip_files`). If you add a new hand-written file under `game/mygame/`, it will be linted by default — that's intended.

### Conventions
- Tailwind compiles to `app/assets/builds/tailwind.css`; `bin/dev` runs `tailwindcss:watch` so edits to `app/assets/tailwind/` rebuild live. Don't hand-edit the built file.
- The three `db/*_schema.rb` files (cable/cache/queue) are the Solid adapters' schemas — not the app schema. There is no `db/schema.rb` yet because no app migrations exist; one appears after the first `bin/rails generate model`.
- For `has_secure_password`, uncomment `bcrypt` in the `Gemfile` first (it ships commented out).

## DragonRuby (`game/`)

- `game/dragonruby` is a Mach-O binary (the engine). Game code lives in `game/mygame/app/main.rb` — the entry point is a `tick` method called every frame. `game/samples/` has 150+ example apps and `game/docs/` has the offline docs.
- The engine binaries and `game/{samples,docs,builds,logs,.dragonruby}` are vendored/gitignored upstream artifacts (see `game/.gitignore`). Avoid reformatting, linting, or "cleaning up" anything outside `game/mygame/` — it's not ours.
- **Editable source is `game/mygame/`.** Edit it freely; it's what ships to `/play`.
- Run the game natively (without Rails): `cd game && ./dragonruby mygame`. Hot-reloads `main.rb` on save while running.

### DragonRuby game served at /play

The Rails app embeds the game as a static HTML5/WASM bundle:

- **`bin/build-game`** runs `dragonruby-publish --only-package --platforms=html5 mygame`, then unzips the result into `public/game/` (wiping it first). It deletes the bundle's standalone `index.html` because Rails renders the canvas itself. `public/game/` is a build artifact — do not edit it by hand or commit it.
- **`GamesController` (`app/controllers/games_controller.rb`)** serves `/play` with `layout "game"`. The game view (`app/views/games/show.html.erb`) renders the `<canvas>` + loader elements inline and loads `dragonruby-html5-loader.js`.
- **`<base href="/game/">`** in `app/views/layouts/game.html.erb` makes the loader's bare relative asset paths resolve against the static bundle in `public/game/`. That layout intentionally omits Turbo/importmap so nothing interferes with the base href.
- **Cross-origin isolation** is required for the WASM runtime's `SharedArrayBuffer`: `GamesController` sets COOP/COEP on the `/play` page, and `GameCrossOriginIsolation` middleware (`app/middleware/game_cross_origin_isolation.rb`, registered in `config/application.rb` before `ActionDispatch::Static`) stamps `Cross-Origin-Resource-Policy: same-origin` onto `/game/` responses. If the game won't load, suspect these headers first.
- **Live dev:** `bin/dev` runs `bin/watch-game` (the `game:` process in `Procfile.dev`), which builds once on startup then re-runs `bin/build-game` on any change under `game/mygame/`. Only `game/mygame/` is watched — artifacts in `public/game/` and `game/builds/` are not, so rebuilds don't loop. The publish step takes a couple seconds; hard-refresh `/play` to see changes (no iframe live-reload).

## Secrets

Never invent placeholder encryption keys or API tokens. If a real secret is needed, ask Mike to add it to Rails credentials (`bin/rails credentials:edit`) rather than hardcoding a fake value.
