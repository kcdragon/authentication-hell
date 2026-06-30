# Authentication Hell

A Rails 8.1 web application that embeds a [DragonRuby GTK](https://dragonruby.org)
game, served at `/play`. The game's source lives in `game/mygame/`; a build step
packages it to HTML5/WASM and Rails serves the result.

## Requirements

- **Ruby 4.0.2** (see `.ruby-version`)
- A working **DragonRuby GTK** is bundled under `game/` (the engine binaries are
  gitignored per DragonRuby's license, so they must be present locally).
- That's it — **SQLite** is the only datastore (primary, cache, queue, and cable
  all live under `storage/`), so there's no Redis/Postgres to install.

## Getting started

```bash
bin/setup    # install gems, prepare the database, and boot the server
```

For day-to-day development, use:

```bash
bin/dev      # http://localhost:3000
```

`bin/dev` (foreman, see `Procfile.dev`) runs three processes together:

- **`web`** — the Rails server
- **`css`** — `tailwindcss:watch`, rebuilding `app/assets/builds/tailwind.css` on edits
- **`game`** — `bin/watch-game`, which builds the game once on startup and
  rebuilds it whenever you change a file under `game/mygame/`

Visit **http://localhost:3000/play** to see the embedded game. After editing the
game, the bundle rebuilds in a couple of seconds — hard-refresh `/play` to pick
up the change.

## The game (`/play`)

The DragonRuby game is embedded as a static HTML5/WASM bundle:

- **Edit** the game in `game/mygame/` (entry point: `game/mygame/app/main.rb`).
- **`bin/build-game`** packages `game/mygame/` to HTML5 and unzips it into
  `public/game/` (a build artifact — not committed, never hand-edited).
- **Rails** serves it at `/play` via `GamesController`. The page is
  cross-origin-isolated (COOP/COEP) so the WASM runtime can use
  `SharedArrayBuffer`.

To run the game natively (outside Rails), use `cd game && ./dragonruby mygame`.

## Tests, linting, and CI

```bash
bin/rails test         # Minitest
bin/rails test:system  # Capybara + Selenium system tests
bin/rubocop            # rubocop-rails-omakase house style
bin/brakeman           # static security scan
bin/bundler-audit      # gem vulnerability audit
bin/ci                 # the full local CI pipeline (config/ci.rb)
```

There is no cloud CI. `bin/ci` is the full pipeline, and on a green run it calls
`gh signoff` to set the green `signoff` commit status — the only required check that
unblocks a PR merge. Run `bin/ci` before pushing, and once it passes the signoff is
recorded automatically.

One-time setup (per developer): `gh extension install basecamp/gh-signoff`.

## Deployment

Deploys run via **Kamal** (Docker) to https://authenticationhell.com:

```bash
bin/kamal deploy
```

The production `/play` bundle is built automatically — the `.kamal/hooks/pre-build`
hook runs `RAILS_ENV=production bin/build-game` before each image build, so the
fresh bundle (`public/production_game_assets/`) is baked into the image. No manual
`bin/build-game` step is needed.
