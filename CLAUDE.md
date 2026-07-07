# CLAUDE.md

Guidance for Claude Code (claude.ai/code) working in this repo.

## Overview

One repo, two things:

1. **A Rails 8.1 web app** (root) — a gamified auth system: a full credential stack (sign-up, sign-in, email confirmation, password reset, TOTP 2FA, recovery codes, WebAuthn passkeys, profile, achievements) wrapped around an embedded game where colliding with an enemy forces re-authentication mid-play.
2. **A bundled copy of DragonRuby GTK** under `game/` — the proprietary engine binary plus our game source in `game/mygame/`. Everything under `game/` except `game/mygame/` is vendored as-is; treat it as a tool, not our code.

**How they connect:** `bin/build-game` packages `game/mygame/` to an HTML5/WASM bundle in `public/game_assets/` (gitignored build artifact); Rails serves it at `/game` via `GamesController`. See "DragonRuby game served at /game".

## Rails app

### Stack
- **Rails 8.1** on the edge `8-1-stable` branch (`bundle update rails` pulls new commits). **Ruby 4.0.2** (`.ruby-version`).
- **SQLite** everywhere including production (separate files per concern under `storage/`); **Solid Queue/Cache/Cable**, no Redis.
- **Hotwire** (Turbo + Stimulus), **importmap** (no JS bundler/npm), **Propshaft**, **Tailwind** via `tailwindcss-rails`.
- Deploy via **Kamal** (Docker); `config/deploy.yml` has placeholder servers.

### Commands
```bash
bin/setup              # install deps, prepare DB, start server (--skip-server, --reset)
bin/dev                # web + Tailwind watcher + game watcher (foreman, Procfile.dev), port 3000
bin/build-game         # package game/mygame/ to HTML5 into public/game_assets/ (one-shot)
bin/watch-game         # build-game once, then rebuild on changes (run by bin/dev)
bin/rails test         # all tests (Minitest); append path or path:line for one
bin/rails test:system  # Capybara + Selenium (not in bin/ci)
bin/test-game          # game's plain-Ruby unit tests (no engine needed)
bin/rubocop            # lint (rubocop-rails-omakase)
bin/brakeman           # security scan
bin/bundler-audit      # gem vulnerability audit
bin/ci                 # full CI pipeline locally (config/ci.rb)
```

### CI
There's no cloud CI — `bin/ci` (defined by `config/ci.rb`) runs everything and, on a green run, records the [gh-signoff](https://github.com/basecamp/gh-signoff) status that unblocks a merge. Always run it yourself after every PR push (each push invalidates the prior signoff); never run `gh signoff` by hand.

RuboCop and Brakeman scope to *our* code only: all of `game/` is excluded except `game/mygame/main.rb` (see `.rubocop.yml` / `config/brakeman.yml`). New hand-written files under `game/mygame/` are linted by default — intended.

### Conventions
- Tailwind builds to `app/assets/builds/tailwind.css` (don't hand-edit); `bin/dev` watches `app/assets/tailwind/`.
- The three `db/*_schema.rb` files are the Solid adapters' schemas, not the app schema. No `db/schema.rb` until the first `bin/rails generate model`.
- For `has_secure_password`, uncomment `bcrypt` in the `Gemfile` first.
- **Never add code comments unless I explicitly ask.** Write self-documenting code instead: extract well-named local variables and private methods so intent is clear from the names and structure, not from a comment.
- Methods not called externally should be `private`. (mruby lacks `private_class_method`, so in `game/mygame/` prefer instance methods on an instantiable class over class methods when you need privacy — see `app/hint_card.rb`.)

### UI conventions
- **Two layouts.** `layouts/application.html.erb` is the standard chrome (centered `container mx-auto md:w-2/3 w-full px-5`, top-right authenticated nav in `shared/_navigation.html.erb`, flash in `shared/_flash.html.erb`). `layouts/game.html.erb` is the minimal game shell.
- **Stock Tailwind v4**, no config/theme. Only custom CSS is the toast keyframes in `app/assets/tailwind/application.css`. Button/input class patterns are copied per view, not extracted: primary `rounded-lg px-3.5 py-2.5 bg-blue-600 hover:bg-blue-500 text-white font-medium`, secondary `bg-gray-800`, destructive `bg-red-600`; inputs `block shadow-sm rounded-md border border-gray-400 focus:outline-solid focus:outline-blue-600 px-3 py-2 w-full`; `h1` is `font-bold text-4xl`.
- **Semantic colors** (keep distinct if restyling): purple = TOTP/2FA, amber/gold = password challenges + achievements, blue = passkeys + primary actions, green = success, red = errors + destructive.
- **Helpers:** `application_helper#avatar_badge`, `totp_helper#totp_qr_code`; `games/*_helper` compute per-user DOM ids for challenge toasts.
- **Overlay toasts** (`app/views/games/_*.html.erb`, bottom-right over canvas): three persistent challenge toasts (`_totp_challenge` purple, `_password_challenge` amber, `_passkey_challenge` blue — inline re-auth forms) and two ephemeral fading ones (`_toast`, `_achievement_toast`). Keyframes and the two-animation split are documented in the Tailwind source.

### Game visual re-skin — "The Onboarding Tape"

The game at `/game` is re-skinned (design handoff in `game/README-video-player.md`) to read as an embedded corporate-training video player — the fiction: a new hire thinks they're *watching* "Authentication Hell" but are *playing* the platformer. **Visual-only** — no geometry/collision/camera/resolution change (fixed 1280×720, world 6400px). Character sprites deferred.

Design tokens + chrome geometry live in `game/mygame/app/constants.rb` (palette as `[r,g,b]`, semantic `BLUE/GREEN/RED/PURPLE/AMBER`, scrubber/bar layout, font paths). Drawing is in `main.rb` (engine-only, untested); entities/levels stay plain-Ruby testable.

- **Scene:** paper wall; the control bar *is* the floor (a dark `INDIGO` band below `GROUND_Y` with an `INDIGO_LIP` the player stands on — bar height = `GROUND_Y` keeps physics unchanged).
- **Platforms** (`entities/platform.rb`): white face + ink border + 7px ink underside, drawn with the platform (no offset shadow, which would crawl against scroll).
- **Video chrome** (`main.rb` `draw_control_bar`/`draw_scrubber`/`draw_transport`): scrubber + faux `m:ss / 3:20` timestamp driven by `player.x / WORLD_W`; play/pause glyph, static CC/speed/fullscreen. No chapter ticks (would spoil enemy positions).
- **States** beyond locked/game-over: **loading → auto-start** (`args.state.started`, world frozen until `/play/me` resolves and `start_run` flips it); **level intro** (`level_intro_at`, a fading chapter card on every level start, scene hidden behind it); **buffering** (quiet in-canvas spinner on collision, the HTML toast owns the challenge); **Video Ended** (replaces game-over; R restarts via `restart_run`).
- **Hearts:** `sprites/ui/heart_hardmode.png` / `heart_empty.png` swapped per life.
- **Fonts** (`game/mygame/fonts/`, ttf): `archivo-black-400`, `space-mono-400`/`-700`, converted from the site's woff2 via fonttools; lowercase-kebab filenames for the case-sensitive WASM lookup; referenced via the label `font:` key.

Future game art must be bare PNGs (IHDR/IDAT/IEND, no ancillary chunks) or it checkerboards in WebGL — see [[reference-dragonruby-png-encoder]]. Solid fills (rects and `x/y,x2/y2,x3/y3` triangles) go on `args.outputs.sprites` with `path: :solid` + `r/g/b` — `args.outputs.solids` is deprecated as of engine 7.13.

## DragonRuby (`game/`)

- Engine is the `game/dragonruby` Mach-O binary; game code is `game/mygame/app/main.rb` (`tick` runs every frame). `game/samples/` has examples, `game/docs/` the offline docs.
- Everything under `game/` except `game/mygame/` is vendored/gitignored upstream — don't reformat or lint it.
- **Editable source is `game/mygame/`** — it's what ships to `/game`.
- **Run `bin/test-game` after any change under `game/mygame/`, before returning.** Entities/levels are plain-Ruby Minitest; update matching tests under `game/mygame/test/` when behavior changes.
- Engine version is in `game/VERSION.txt` (date + hash; the number is in the top of `game/CHANGELOG-CURR.txt`).
- Upgrading the engine to a new release has its own procedure — use the `upgrade-dragonruby` skill.

### DragonRuby game served at /game

- **`bin/build-game`** runs `dragonruby-publish --only-package --platforms=html5 mygame`, unzips into `public/game_assets/` (wiped first), and deletes the bundle's `index.html` (Rails renders the canvas). Don't edit or commit `public/game_assets/`.
- **`GamesController`** serves `/game` with `layout "game"`; `show.html.erb` renders the `<canvas>` + loader inline.
- **`<base href="/game_assets/">`** in `layouts/game.html.erb` resolves the loader's bare asset paths against the bundle. The layout omits `javascript_importmap_tags` so those paths aren't rewritten — so any JS the view needs loads via a page-scoped `<script type="importmap">` with absolute, digested `asset_path(...)` URLs (as `show.html.erb` does for Turbo).
- **Collision → TOTP re-auth (Turbo Streams):** the game POSTs to `/games/totp/collision` (`Games::TotpController#collision`, CSRF skipped — WASM can't carry a token; still same-origin + session-gated, only sets a flag + broadcasts). That `broadcast_replace_to`s the persistent `_totp_challenge` toast (a code form) scoped to `Current.user`; `show.html.erb` subscribes via `turbo_stream_from Current.user, :toasts`. The form submits to `/games/totp/unlock` (CSRF kept); a valid code clears the flag and removes the toast. The game freezes on collision and polls `/games/totp/status` until it clears. No Stimulus/ActionCable of our own.
- **Cross-origin isolation** (for the WASM `SharedArrayBuffer`): `GamesController` sets COOP/COEP on `/game`, and `GameCrossOriginIsolation` middleware stamps `Cross-Origin-Resource-Policy: same-origin` on `/game_assets/`. Suspect these headers first if the game won't load.
- **Live dev:** `bin/dev` runs `bin/watch-game` (rebuilds on changes under `game/mygame/` only). Publish takes a couple seconds; hard-refresh `/game`.

### Level editor (dev-only)

In development, `/game` boots to a Play/Edit menu; the editor (`game/mygame/app/editor/`, plus `Editor::*` on the Rails side) authors levels visually and saves them as JSON through dev-only endpoints. New levels are drafts in the gitignored, worktree-shared `level_drafts/`; promoting from the editor moves them to the committed `game/mygame/data/levels/`, which `JsonLevel` rebuilds into playable levels.

## Secrets

Never invent placeholder encryption keys or API tokens. If a real secret is needed, ask Mike to add it via `bin/rails credentials:edit`.
