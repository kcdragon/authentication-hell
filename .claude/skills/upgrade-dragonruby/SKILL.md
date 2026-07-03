---
name: upgrade-dragonruby
description: Upgrade the vendored DragonRuby GTK engine in game/ to a new release without clobbering our game source. Use when bumping the DragonRuby version, swapping in a downloaded dragonruby-*-gtk-macos.zip, or when the game's engine/WASM runtime needs updating.
---

# Upgrading DragonRuby

The release zip unzips to `dragonruby-macos/` (engine + a stock `mygame/`). Replace our vendored copy **without clobbering `game/mygame/`** (our source + `devid`/`devtitle` metadata):

1. `unzip -q ~/Documents/dragonruby-X-Y-gtk-macos.zip -d /tmp/drXY` → `/tmp/drXY/dragonruby-macos/`.
2. Copy every entry except `mygame` into `game/`, **including dotfiles** — the `.dragonruby/` dir holds the HTML5/WASM build stub that `dragonruby-publish` bakes in. A bare `for e in *` misses it, so `bin/build-game` would silently ship the *old* web runtime. Enable dotglob:
   ```bash
   cd /tmp/drXY/dragonruby-macos
   setopt local_options dotglob 2>/dev/null || shopt -s dotglob
   for e in *; do [ "$e" = mygame ] && continue; rm -rf "game/$e" && cp -R "$e" "game/$e"; done
   ```
3. Read the new `game/CHANGELOG-CURR.txt` — engine WASM fixes can let us drop client-side workarounds in `show.html.erb`.
4. `bin/build-game`, then confirm the new engine actually shipped: `grep -c Module.HEAPU8.set public/game_assets/dragonruby-wasm.js` (0 on 7.7+; nonzero = stale stub leaked). Load `/game`.

## WASM bug history

7.x before 7.7 had a broken HTML5 `http_get` (`Module.HEAPU8` undefined, froze the tick loop at tick 0); we polyfilled it in `show.html.erb`. **7.7 fixed it** and the polyfill was removed. If a future upgrade regresses `http_get`, that's where a workaround goes.
