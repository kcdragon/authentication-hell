# Talks

Slide decks for "Welcome to Authentication Hell", built with [Slidev](https://sli.dev).

Each talk is its own **self-contained** Slidev project (its own `package.json`
and `node_modules`). They're kept in this repo so slides can pull screenshots,
gifs, and live code ranges straight from the game and Rails app.

### Theme

The decks use a **custom theme** (no external Slidev theme) that mirrors the
app's "HARD MODE" neo-brutalist design system: the same tokens, the same
self-hosted fonts (Archivo Black / Space Grotesk / Space Mono), and the same
hard-offset-shadow + 3px-ink-border look. It lives per-deck in:

- `style.css` — tokens, fonts, base styles, and helper classes
  (`.ah-card`, `.ah-badge--{totp,password,passkey,success,error}`, role-color
  text like `.ah-passkey`).
- `layouts/cover.vue` and `layouts/section.vue` — the inked title/section slides.
- `fonts/` — woff2 copied from `app/assets/fonts/` (kept in sync by hand; the
  app rarely changes fonts).

The semantic colors carry the same meaning as in the app — **purple** = TOTP,
**amber** = password/achievements, **blue** = passkey/primary, **green** =
success, **red** = error — so a "passkey" slide reads the same as the passkey
UI. Use the helper classes in slide markup to stay on-palette.

The Rails pipeline ignores `talks/` entirely — it's excluded from RuboCop,
Brakeman, and `bin/ci`. Node tooling lives only inside each deck.

## Decks

| Dir            | Event      | Status      |
| -------------- | ---------- | ----------- |
| `phillyrb/`    | Philly.rb  | In progress |
| `rubyconf/`    | RubyConf   | Not started |

## Working on a deck

```bash
cd talks/phillyrb
npm install          # first time only
npm run dev          # live preview at http://localhost:3030
```

Press `c` in the browser for presenter/notes mode.

### Pulling in game/app assets

- **Images:** drop them in `<deck>/images/` and reference `![alt](./images/foo.png)`.
- **Live code:** import line ranges from the repo with Slidev's transclusion,
  e.g. `<<< ../../../app/models/user.rb#login {1-12}`. Paths are relative to
  the deck's `slides.md` (`../../../` climbs back to the repo root).

### Export

```bash
npm run build        # static site -> dist/
npm run export       # PDF (needs Playwright; `npx playwright install chromium`)
```

Both outputs are gitignored.

## Workflow: Philly.rb → RubyConf

Present **Philly.rb first**. Once it's delivered, copy it over as the starting
point for RubyConf and refine from there:

```bash
cp -R talks/phillyrb talks/rubyconf
# then update package.json "name", the title/footer in slides.md,
# and tailor the content for the RubyConf audience.
```

Keeping them as separate directories (rather than branches or one shared deck)
means each talk freezes at the version you actually gave, and the two can drift
independently.
