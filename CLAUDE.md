# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Two things live in one repo:

1. **A Rails 8.1 web application** (root) — generated with `rails new --css tailwind --edge`. No domain/auth models exist yet (`app/models` has only `ApplicationRecord`); the presumable goal, per the repo name, is authentication. The one real feature so far is embedding the DragonRuby game (below) at `/game`.
2. **A bundled copy of DragonRuby GTK** under `game/` — the proprietary game engine binary plus a sample game in `game/mygame/`. The engine and `game/{samples,docs,builds,logs}` are vendored as-is; treat them as a tool, not application code. The game *source* in `game/mygame/` is ours to edit, and the Rails app serves a built copy of it.

**How the two connect:** `bin/build-game` packages `game/mygame/` to an HTML5/WASM bundle and unzips it into `public/game_assets/` (a static, gitignored build artifact). Rails serves it at `/game` via `GamesController`. So the game is no longer standalone — it's a build input to the Rails app. See "DragonRuby game served at /game" below.

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
bin/build-game         # package game/mygame/ to HTML5 and unzip into public/game_assets/ (one-shot)
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

**`bin/ci` is the fastest way to catch locally what the GitHub workflow checks**, so it's worth running after implementing a change — but you don't need to run the full suite before opening a PR. The GitHub Actions workflow runs the same pipeline on every PR and will catch any failures.

RuboCop and Brakeman are scoped to *our* code only: everything under `game/` is excluded except `game/mygame/`, and within that, only `main.rb` is linted (`repl.rb` is DragonRuby's vendored console scratch file). See `.rubocop.yml` (`AllCops/Exclude`) and `config/brakeman.yml` (`skip_files`). If you add a new hand-written file under `game/mygame/`, it will be linted by default — that's intended.

### Conventions
- Tailwind compiles to `app/assets/builds/tailwind.css`; `bin/dev` runs `tailwindcss:watch` so edits to `app/assets/tailwind/` rebuild live. Don't hand-edit the built file.
- The three `db/*_schema.rb` files (cable/cache/queue) are the Solid adapters' schemas — not the app schema. There is no `db/schema.rb` yet because no app migrations exist; one appears after the first `bin/rails generate model`.
- For `has_secure_password`, uncomment `bcrypt` in the `Gemfile` first (it ships commented out).
- Comments are sparse. Add one only where the code isn't self-explanatory, and explain the *why*, not the *what* — never restate the code. Put it on (or directly above) the line it describes, not at the top of a method describing something lower down. Keep it to a single sentence unless the issue is genuinely complicated.

### UI surface and visual conventions

The app is a gamified auth system: a full credential stack (sign-up, sign-in, email confirmation, password reset, TOTP 2FA, recovery codes, WebAuthn passkeys, profile, achievements) wrapped around the embedded game, where colliding with an enemy forces re-authentication mid-play.

- **Two layouts.** `layouts/application.html.erb` is the standard chrome: a centered `container mx-auto md:w-2/3 w-full px-5` content column with a top-right authenticated nav (`shared/_navigation.html.erb` — avatar badge + username dropdown: Play / Profile / Passkeys / Two-factor / Sign out) and flash via `shared/_flash.html.erb`. `layouts/game.html.erb` is the minimal game shell (see the DragonRuby section). Pages served under each look different by design.
- **Styling is stock Tailwind v4**, no customization: system-ui fonts, default palette, no `tailwind.config.js`, no `@theme` tokens. The only custom CSS is the toast keyframes in `app/assets/tailwind/application.css`. Recurring class patterns (not extracted into helpers — copied per view): primary button `rounded-lg px-3.5 py-2.5 bg-blue-600 hover:bg-blue-500 text-white font-medium`; secondary/passkey button uses `bg-gray-800`; destructive uses `bg-red-600`; inputs `block shadow-sm rounded-md border border-gray-400 focus:outline-solid focus:outline-blue-600 px-3 py-2 w-full`; page `h1` is `font-bold text-4xl`.
- **Semantic color system** — these hues carry meaning and recur across views; keep them distinct if restyling: **purple** = TOTP/2FA, **amber/gold** = password challenges + achievements, **blue** = passkeys (and primary actions), **green** = enabled/success status, **red** = errors + destructive actions.
- **Presentation helpers:** `application_helper#avatar_badge` (uploaded variant or initial-letter fallback), `totp_helper#totp_qr_code` (inline SVG via rqrcode). The `games/*_helper` files only compute per-user DOM ids for the challenge toasts.
- **Game overlay toasts** (`app/views/games/_*.html.erb`, fixed bottom-right over the canvas): the three persistent challenge toasts (`_totp_challenge` purple, `_password_challenge` amber, `_passkey_challenge` blue — each an inline re-auth form dismissed only by a valid answer) and two ephemeral auto-fading ones (`_toast` generic collision, `_achievement_toast` gold). The keyframes (`toast-fade`/`toast-collapse` for ephemeral, `challenge-toast-in` for persistent) live in the Tailwind source; comments there explain the two-animation split.

#### Game visual re-skin — "The Onboarding Tape" (video-player frame)

The game at `/game` is re-skinned (Claude Design handoff in `game/README-video-player.md`) to read as an embedded **corporate-training video player**: the fiction is that a new hire thinks they're *watching* "Authentication 101," but they're actually *playing* the platformer. It's **visual-only** — no geometry, collision, camera, or resolution change (fixed 1280×720, world 6400px wide). Character art (player + enemy sprites) was **deferred** — this pass is environment + video-player chrome only.

Design tokens + chrome geometry live in `game/mygame/app/constants.rb` (palette `PAPER/INK/INDIGO/...` as `[r,g,b]`, the semantic `BLUE/GREEN/RED/PURPLE/AMBER`, scrubber/bar layout, font paths). The drawing all lives in `main.rb` (engine-only, untested); the entities/levels stay plain-Ruby testable.

- **Scene:** warm-paper wall (`PAPER`); the bottom **control bar = the floor** — a dark `INDIGO` band filling everything below `GROUND_Y` with an `INDIGO_LIP` lip the player stands on. Keeping the bar height = `GROUND_Y` means physics is unchanged (the lip lands exactly on the existing ground line).
- **Platforms** (`entities/platform.rb`): white card face + `INDIGO` ink border + a 7px ink underside band (drawn *with* the platform, no offset drop-shadow — a baked shadow would crawl against the scroll).
- **Video chrome** (`main.rb` `draw_control_bar`/`draw_scrubber`/`draw_transport`): a scrubber (track / cosmetic "buffered" bar / green progress fill / playhead) whose fill + a faux `m:ss / 3:20` timestamp are driven by `player.x / WORLD_W`; a play/pause glyph and static CC/speed/fullscreen affordances. **No chapter ticks** (decided against — they'd spoil enemy positions).
- **New states** (beyond the original locked/game-over):
  - **Poster / paused start** (`args.state.started`): the game opens paused behind a giant blue play button + "AUTHENTICATION 101" card; a click or space "presses play" and starts the run. The world is frozen until then (`update_world` is gated on `started`).
  - **Buffering** (replaces the old `draw_challenge_hint`): on collision the in-canvas treatment is quiet — a spinner + one mono line tinted to the enemy's color pointing at the HTML toast (the toast still owns the loud challenge card).
  - **Video Ended** (replaces `draw_game_over`): indigo dim + Archivo Black "Video Ended" + red rule + "press R to replay"; **R restarts the run** (`restart_run` resets player/level to the tutorial).
- **Hearts:** `sprites/ui/heart_hardmode.png` (full) / `heart_empty.png` (spent) swapped per life instead of alpha-fading one sprite.
- **Fonts** (`game/mygame/fonts/`, ttf): `archivo-black-400` (display, "Video Ended"), `space-mono-400`/`-700` (HUD/greeting/hints/timestamp) — **converted from the site's self-hosted woff2** (`app/assets/fonts/`) via fonttools so the glyphs match the site exactly. Lowercase-kebab filenames so the case-sensitive WASM asset lookup resolves. Referenced via the label `font:` key (path relative to `mygame/`).

Any future game art must ship as bare PNGs (IHDR/IDAT/IEND, no ancillary chunks) or it checkerboards in the WebGL build — see [[reference-dragonruby-png-encoder]]. Note: solid-color **triangles** go on `args.outputs.solids` with `x/y,x2/y2,x3/y3` + `r/g/b` (not a separate `triangles` output).

## DragonRuby (`game/`)

- `game/dragonruby` is a Mach-O binary (the engine). Game code lives in `game/mygame/app/main.rb` — the entry point is a `tick` method called every frame. `game/samples/` has 150+ example apps and `game/docs/` has the offline docs.
- The engine binaries and `game/{samples,docs,builds,logs,.dragonruby}` are vendored/gitignored upstream artifacts (see `game/.gitignore`). Avoid reformatting, linting, or "cleaning up" anything outside `game/mygame/` — it's not ours.
- **Editable source is `game/mygame/`.** Edit it freely; it's what ships to `/game`.
- Run the game natively (without Rails): `cd game && ./dragonruby mygame`. Hot-reloads `main.rb` on save while running.
- Current engine version is in `game/VERSION.txt` (a date + git hash, no semver — the version number lives in the top heading of `game/CHANGELOG-CURR.txt`).

### Upgrading DragonRuby

DragonRuby is distributed as a zip (e.g. `dragonruby-7-7-gtk-macos.zip`) that unzips to a single `dragonruby-macos/` folder containing the engine plus a stock `mygame/`. To upgrade, replace our vendored copy with the new release **without clobbering `game/mygame/`** (our game source + customized metadata):

1. Unzip the release to a temp dir: `unzip -q ~/Documents/dragonruby-X-Y-gtk-macos.zip -d /tmp/drXY` → contents land in `/tmp/drXY/dragonruby-macos/`.
2. Copy every entry **except `mygame`** into `game/`, overwriting. **Critically, include dotfiles** — the release ships a `.dragonruby/` directory holding the per-platform build *stubs* (including the HTML5/WASM stub that `dragonruby-publish` bakes into the web bundle). A bare `for e in *` glob misses `.dragonruby`, leaving the old stubs in place — `bin/build-game` then silently produces a bundle running the **previous** engine's web runtime even though the native binaries upgraded. Enable dotglob (or list it explicitly):
   ```bash
   cd /tmp/drXY/dragonruby-macos
   setopt local_options dotglob 2>/dev/null || shopt -s dotglob   # zsh/bash: make * match dotfiles
   for e in *; do [ "$e" = mygame ] && continue; rm -rf "game/$e" && cp -R "$e" "game/$e"; done
   ```
   This swaps the binaries (`dragonruby`, `dragonruby-publish`, `dragonruby-httpd` — only `-httpd` is tracked; the other two are gitignored, so they won't show in `git status`), the `samples/`/`docs/`, the committed constants (`VERSION.txt`, `CHANGELOG-*.txt`, `README.txt`, `eula.txt`, fonts/images), **and `.dragonruby/` (the build-stub cache)**. Our `game/mygame/` (game code in `app/main.rb`, our `devid`/`devtitle` flags in `metadata/game_metadata.txt`) is left intact, as are local-only dirs the release doesn't ship (`builds/`, `logs/`, `tmp/`).
3. Read the new release's `game/CHANGELOG-CURR.txt` for what changed — engine HTML5/WASM fixes can let us delete client-side workarounds in `app/views/games/show.html.erb` (see below).
4. Rebuild and verify: `bin/build-game`, then **confirm the served bundle is actually the new engine** — e.g. `grep -c Module.HEAPU8.set public/game_assets/dragonruby-wasm.js` (0 on 7.7+; nonzero means a stale `.dragonruby/` stub leaked through). Then load `/game`.

**Engine WASM bug history:** 7.x before 7.7 shipped a broken HTML5 `http_get` (Emscripten compiled `HEAPU8` as a runtime local never assigned back onto `Module`, so the first successful same-origin request threw `Cannot read properties of undefined (reading 'set')` and froze the tick loop at tick 0). We worked around it with a JS polyfill in `show.html.erb` that pre-created `Module.wasmMemory` + `HEAPU8` getters. **7.7 fixed this** (changelog: "Fixed HTTP apis for web builds. Emscripten 5 changed `Module.HEAPU8.set` to `HEAPU8.set`"), so the polyfill was removed. If a future upgrade reintroduces a WASM/`http_get` regression, that script block is where a workaround would go.

### DragonRuby game served at /game

The Rails app embeds the game as a static HTML5/WASM bundle:

- **`bin/build-game`** runs `dragonruby-publish --only-package --platforms=html5 mygame`, then unzips the result into `public/game_assets/` (wiping it first). It deletes the bundle's standalone `index.html` because Rails renders the canvas itself. `public/game_assets/` is a build artifact — do not edit it by hand or commit it.
- **`GamesController` (`app/controllers/games_controller.rb`)** serves `/game` with `layout "game"`. The game view (`app/views/games/show.html.erb`) renders the `<canvas>` + loader elements inline and loads `dragonruby-html5-loader.js`.
- **`<base href="/game_assets/">`** in `app/views/layouts/game.html.erb` makes the loader's bare relative asset paths resolve against the static bundle in `public/game_assets/`. That layout intentionally omits the app-wide `javascript_importmap_tags` so the loader's bare paths don't get rewritten. The trade-off: any Hotwire/JS the `/game` view needs must be loaded with a **page-scoped `<script type="importmap">` whose specifiers are absolute, digested `asset_path(...)` URLs** — absolute so the base href leaves them alone. `show.html.erb` does exactly this to load Turbo for the collision toasts (below).
- **Collision → TOTP re-auth (Turbo Streams):** colliding with the enemy forces the player to re-authenticate. The game POSTs to `/games/totp/collision` (`Games::TotpController#collision`, CSRF skipped for that action since the WASM client can't carry a token — it's still same-origin + session-gated and only sets a session flag + broadcasts), which `Turbo::StreamsChannel.broadcast_replace_to`s the persistent `games/_totp_challenge.html.erb` toast (a code form) onto the page, scoped to `Current.user`. `show.html.erb` subscribes with `turbo_stream_from Current.user, :toasts` and holds an empty per-player target (id from `dom_id`, via `Games::TotpHelper#totp_challenge_toast_id`) the broadcast replaces. The toast's form submits to `/games/totp/unlock` (Turbo form, CSRF kept via `csrf_meta_tags`); a valid `verify_totp` clears the session flag and removes the toast. The game freezes movement on collision and polls `/games/totp/status` until the lock clears. (The older fading `games/_toast.html.erb` + `toast-fade` CSS still exists for ephemeral messages.) No Stimulus/ActionCable JS of our own — Turbo does the DOM work.
- **Cross-origin isolation** is required for the WASM runtime's `SharedArrayBuffer`: `GamesController` sets COOP/COEP on the `/game` page, and `GameCrossOriginIsolation` middleware (`app/middleware/game_cross_origin_isolation.rb`, registered in `config/application.rb` before `ActionDispatch::Static`) stamps `Cross-Origin-Resource-Policy: same-origin` onto `/game_assets/` responses. If the game won't load, suspect these headers first.
- **Live dev:** `bin/dev` runs `bin/watch-game` (the `game:` process in `Procfile.dev`), which builds once on startup then re-runs `bin/build-game` on any change under `game/mygame/`. Only `game/mygame/` is watched — artifacts in `public/game_assets/` and `game/builds/` are not, so rebuilds don't loop. The publish step takes a couple seconds; hard-refresh `/game` to see changes (no iframe live-reload).

## Secrets

Never invent placeholder encryption keys or API tokens. If a real secret is needed, ask Mike to add it to Rails credentials (`bin/rails credentials:edit`) rather than hardcoding a fake value.
