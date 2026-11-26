# CLAUDE.md

Guidance for Claude Code (claude.ai/code) working in this repo.

## Overview

One repo, two things:

1. **A Rails 8.2 (edge) web app** (root) — a gamified auth system: a full credential stack (sign-up, sign-in, email confirmation, password reset, TOTP 2FA, recovery codes, WebAuthn passkeys, profile, achievements) wrapped around an embedded game where colliding with an enemy forces re-authentication mid-play.
2. **DragonRuby GTK** under `game/` — our game source in `game/mygame/`, plus the upstream engine files. The engine binaries (`game/dragonruby`, `game/dragonruby-publish`, `game/.dragonruby/`) are gitignored per the DragonRuby license, macOS-only, and copied into each worktree through `.worktreeinclude`. Everything under `game/` except `game/mygame/` is upstream; treat it as a tool, not our code.

**How they connect:** `bin/build-game` packages `game/mygame/` to an HTML5/WASM bundle in `public/<env>_game_assets/<digest>/` (gitignored build artifact); Rails serves it at `/game` via `GamesController`. See "DragonRuby game served at /game".

## Rails app

### Stack
- **Rails 8.2.0.alpha** tracking `rails/rails` `main` (`bundle update rails --conservative` pulls new commits), required by HotCell until 8.2 ships. **Ruby 4.0.10** (`.ruby-version`).
- **Uploaded images are processed in a [HotCell](https://github.com/basecamp/hotcell) sidecar**, not in Rails: avatar analysis and variants run libvips in the `active_storage` cell (no network, no secrets, read-only). The app has no libvips or `ruby-vips`. The cell lives in `hotcell/` (its own Gemfile, Dockerfile, limits) and `bin/hotcell` runs it locally; the dev server and the test suite start it for you. Its sockets are under `$XDG_RUNTIME_DIR/hotcell-<checkout hash>` because worktree paths exceed the 108-byte socket limit. In production it's the `active_storage` Kamal accessory; ship cell changes with `bin/deploy-hotcell` (Kamal never rebuilds accessories on `kamal deploy`).
- **SQLite** everywhere including production (separate files per concern under `storage/`); **Solid Queue/Cache/Cable**, no Redis.
- **Hotwire** (Turbo + Stimulus), **importmap** (no JS bundler), **Propshaft**, **Tailwind** via `tailwindcss-rails`. npm is only for dev tools: Playwright (system tests) and the herb ERB linter (`bin/herb`).
- Deploy via **Kamal** (Docker) to the real host in `config/deploy.yml` (`authenticationhell.com`).

### Commands
```bash
dev-server start       # this worktree's server on its leased port (prints the URL); dev-server stop when done
bin/setup --skip-server  # install deps (gems, npm, Playwright), prepare DB (--reset to rebuild it)
bin/build-game         # package game/mygame/ to HTML5 into public/<env>_game_assets/ (one-shot; needs the macOS engine)
bin/watch-game         # build-game once, then rebuild on changes (run by the dev server)
bin/rails test         # all tests (Minitest); append path or path:line for one
bin/rails test:system  # Capybara + Playwright (not in bin/ci)
bin/test-game          # game's plain-Ruby unit tests (no engine needed, runs on Linux)
bin/rubocop            # lint (rubocop-rails-omakase)
bin/herb               # ERB lint
bin/brakeman           # security scan
bin/bundler-audit      # gem vulnerability audit
bin/ci                 # full CI pipeline locally (config/ci.rb)
```

`dev-server start` runs `bin/dev` with `PORT` set, which runs `Procfile.dev` under foreman: web, Tailwind watcher (`css`), game watcher (`game`, `bin/watch-game`) and the HotCell sidecar (`cell`). Never run `bin/dev` directly, and never plain `bin/setup` (it execs `bin/dev` on 3000).

### CI
There's no cloud CI — `bin/ci` (defined by `config/ci.rb`) runs everything. A `PostToolUse` hook in `.claude/settings.json` runs `bin/ci` automatically after every `git push` — don't run it yourself after pushing.

RuboCop and Brakeman exclude only the upstream engine dirs (`game/{builds,docs,logs,samples,tmp,.dragonruby}`), DragonRuby's `game/mygame/app/repl.rb`, and the `talks/` decks (see `.rubocop.yml` / `config/brakeman.yml`). Everything else under `game/mygame/` is linted — intended.

### Conventions
- Tailwind builds to `app/assets/builds/tailwind.css` (don't hand-edit); the dev server's `css` process watches `app/assets/tailwind/`.
- **Never add code comments unless I explicitly ask.** Write self-documenting code instead: extract well-named local variables and private methods so intent is clear from the names and structure, not from a comment.
- Methods not called externally should be `private`. (mruby lacks `private_class_method`, so in `game/mygame/` prefer instance methods on an instantiable class over class methods when you need privacy — see `app/ui/time_hint.rb`.)

### UI conventions
- **Layouts** (`app/views/layouts/`):
  - `application` — the standard chrome: header with logo and top-right authenticated nav (`shared/_navigation.html.erb`), `main.container mx-auto px-5`, flash in `shared/_flash.html.erb`.
  - `game_page` — `/game`: the header plus the game page, with `turbo-visit-control: reload` (cross-origin isolation needs a full navigation).
  - `game_frame` — `/game/frame`, the iframe the game runs in (see below).
  - `attract` — the `/attract` conference kiosk screen.
  - `mailer`.
- **Tailwind v4 with a design system** in `app/assets/tailwind/application.css`: an `@theme` block of tokens (`paper`/`card`/`ink`/`muted` neutrals, semantic `totp`/`password`/`passkey`/`api`/`success`/`error` colors, `font-display` Archivo Black / `font-sans` Space Grotesk / `font-mono` Space Mono, `brut` radius and offset shadows), self-hosted fonts, and `ah-*` component classes (`ah-card`, `ah-btn` + `--primary/--secondary/--destructive/--outline/--ghost`, `ah-input`, `ah-label`, `ah-badge--*`, `ah-flash--*`, `ah-otp`, …). Use those classes rather than raw utility stacks for buttons, inputs and cards. Toast keyframes live there too; `attract.css` holds the kiosk animations.
- **Semantic colors** (keep distinct if restyling): purple `totp` = TOTP/2FA, amber `password` = password challenges + achievements, blue `passkey` = passkeys + primary actions, teal `api` = API keys, green = success, red = errors + destructive.
- **Helpers:** `application_helper#avatar_badge`, `totp_helper#totp_qr_code`; `games/*_helper` compute per-user DOM ids for the game toasts.
- **Overlay toasts** (`app/views/games/_*.html.erb`, bottom-right over the game, broadcast on `turbo_stream_from Current.user, :toasts`) go into one of two containers named in `Game::Toasts`:
  - **Permanent** (`PERMANENT_CONTAINER`, stay until resolved): the re-auth challenges `_totp_challenge` (purple), `_password_challenge` (amber), `_passkey_challenge` (blue); the level challenges `_level_totp_challenge` (with `_level_totp_dev_code` in development) and `_level_api_key_challenge`; and `_certificate_toast` once the game is beaten.
  - **Ephemeral** (`EPHEMERAL_CONTAINER`, fade out): `_toast`, `_achievement_toast`, `_best_time_toast`, `_level_totp_result`.
  - The `_playlist` sidebar beside the game is broadcast separately on `Current.user, :playlist`.

### Game visual re-skin — "The Onboarding Tape"

The game reads as an embedded corporate-training video player — the fiction: a new hire thinks they're *watching* "Authentication Hell" but are *playing* the platformer. Fixed 1280×720.

Design tokens + chrome geometry live in `game/mygame/app/constants.rb` (palette as `[r,g,b]`, semantic `BLUE/GREEN/RED/PURPLE/AMBER`, scrubber/bar layout, font paths). `Game` (`app/game.rb`) owns the run state and draws through one class per piece under `app/ui/` (`Ui::Background`, `Ui::ControlBar`, `Ui::Scrubber`, `Ui::Transport`, `Ui::Hearts`, the overlays); `main.rb` only reads the baked server origin and ticks the `Shell`. Entities/levels stay plain-Ruby testable.

- **Scene:** paper wall; the control bar *is* the floor (a dark `INDIGO` band below `GROUND_Y` with an `INDIGO_LIP` the player stands on — bar height = `GROUND_Y` keeps physics unchanged).
- **Platforms** (`entities/platform.rb`): white face + ink border + 7px ink underside, drawn with the platform (no offset shadow, which would crawl against scroll).
- **Video chrome** (`Ui::ControlBar`, `Ui::Scrubber`, `Ui::Transport`): scrubber + faux timestamp driven by level progress; play/pause glyph, CC toggle, static speed/fullscreen. No chapter ticks (would spoil enemy positions).
- **States:** **loading → auto-start** (`Game#started?`, world frozen until `/game/start` (`Network::Start`) resolves and `start_run` flips it); **level intro** (`begin_level_intro` starts the level clock, `Ui::LevelIntro` draws the chapter card); **buffering** (`Ui::BufferingOverlay`, a quiet in-canvas spinner on collision while the HTML toast owns the challenge); **paused**; **Video Ended** (`Ui::VideoEnded`, replaces game-over; R restarts via `restart_run`); **Course Complete** (`Ui::CourseComplete`).
- **Hearts:** `sprites/ui/heart_hardmode.png` / `heart_empty.png` swapped per life.
- **Fonts** (`game/mygame/fonts/`, ttf): `archivo-black-400`, `space-mono-400`/`-700`, converted from the site's woff2 via fonttools; lowercase-kebab filenames for the case-sensitive WASM lookup; referenced via the label `font:` key.

Game art must be bare PNGs (only critical chunks such as IHDR/IDAT/IEND, no ancillary ones) or it checkerboards in WebGL — `bin/build-qr-pieces` shows how to strip them. Solid fills (rects and `x/y,x2/y2,x3/y3` triangles) go on `args.outputs.sprites` with `path: :solid` + `r/g/b` — `args.outputs.solids` is deprecated as of engine 7.13.

## DragonRuby (`game/`)

- The engine (`game/dragonruby`, `game/dragonruby-publish`, `game/.dragonruby/`) is gitignored and macOS-only; `.worktreeinclude` copies it into new worktrees. On Linux it's absent, so `bin/build-game` (and the dev server's `game` process) can't build there — `/game` then has no bundle. `bin/test-game` doesn't need it and runs anywhere.
- Game entry point is `game/mygame/app/main.rb` (`tick` runs every frame, handing off to `Shell` and `Game`). `game/samples/` has examples, `game/docs/` the offline docs.
- Everything under `game/` except `game/mygame/` is upstream — don't reformat or lint it.
- **Editable source is `game/mygame/`** — it's what ships to `/game`.
- **Run `bin/test-game` after any change under `game/mygame/`, before returning.** Entities/levels are plain-Ruby Minitest; update matching tests under `game/mygame/test/` when behavior changes.
- Engine version is in `game/VERSION.txt` (date + hash; the number is in the top of `game/CHANGELOG-CURR.txt`).
- Upgrading the engine to a new release has its own procedure — use the `upgrade-dragonruby` skill.

### DragonRuby game served at /game

- **`bin/build-game`** bakes the Rails origin into `game/mygame/app/server_config.txt` (gitignored; the WASM can't read env vars). In development that's `GAME_SERVER_ORIGIN`, else `http://localhost:` + `CONDUCTOR_PORT`, `PORT` (set by `dev-server`), or 3000; other environments must pass `GAME_SERVER_ORIGIN`. It then runs `dragonruby-publish --only-package --platforms=html5 mygame`, wipes `public/<env>_game_assets/`, unzips into `public/<env>_game_assets/<digest>/`, deletes the bundle's `index.html`, and patches the loader's iframe guard (see the `upgrade-dragonruby` skill). Don't edit or commit `public/*_game_assets/`.
- **`GamesController`** (`layout "game_page"`): `show` (`/game`) renders the page with the game in a same-origin `<iframe>` of `frame` (`/game/frame`, `layout "game_frame"`), the playlist and the toast containers; `start` (`/game/start`) is the JSON the game fetches on boot (start level, promoted levels, drop chances, editor flag).
- **`games/frame.html.erb`** has the `<canvas>`, loader elements and `dragonruby-html5-loader.js`. `layouts/game_frame.html.erb` sets `<base href="<%= game_assets_path %>">` so the loader's bare asset paths resolve against the digested bundle, and omits `javascript_importmap_tags` so those paths aren't rewritten — any JS the frame needs loads via a page-scoped `<script type="importmap">` with absolute, digested `asset_path(...)` URLs (as `frame.html.erb` does for Stimulus).
- **Game → Rails routes** (`namespace :games` in `config/routes.rb`, controllers in `app/controllers/games/`). Each challenge has `status` (polled by the game while frozen) and `start`, plus its own completion routes:
  - `totp/{status,start,complete}` (`Games::TotpChallengeController`)
  - `passkey/{status,start,options,complete}`
  - `password/{status,start,complete}`
  - `level_totp/{status,start,register,submit}`
  - `level_api_key/{status,start,create}`
  - `levels/{complete,playing,milestone}`, `death`, `defeats`
- **Collision → re-auth (Turbo Streams):** e.g. for TOTP, the game POSTs `totp/start` (CSRF skipped — WASM can't carry a token; still same-origin + session-gated). It records a `game_challenges` row on `Current.session` and `broadcast_append_to`s `_totp_challenge` into the permanent toast container. The toast's form posts to `totp/complete` (CSRF kept); a valid code deletes the challenge and removes the toast. The game freezes and polls `totp/status` until `locked` is false. The password and passkey challenges follow the same shape; the level challenges have their own register/submit/create steps.
- **Cross-origin isolation** (for the WASM `SharedArrayBuffer`): `GamesController` sets COOP/COEP on `show` and `frame`, and `GameCrossOriginIsolation` middleware stamps CORP/COEP/COOP and an immutable cache header on `/<env>_game_assets/`. Suspect these headers first if the game won't load.
- **Live dev:** the dev server runs `bin/watch-game` (rebuilds on changes under `game/mygame/` only, on macOS). Publish takes a couple seconds; hard-refresh `/game`.

### Level editor (dev-only)

In development, `/game` boots to a Play/Edit menu; the editor (`game/mygame/app/editor/`, plus `Editor::*` on the Rails side) authors levels visually and saves them as JSON through dev-only endpoints. New levels are drafts in the gitignored, worktree-shared `level_drafts/`; promoting from the editor moves them to the committed `game/mygame/data/levels/`, which `JsonLevel` rebuilds into playable levels.

## Secrets

Never invent placeholder encryption keys or API tokens. If a real secret is needed, ask Mike to add it via `bin/rails credentials:edit`.
