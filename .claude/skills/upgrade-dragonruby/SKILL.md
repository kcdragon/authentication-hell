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
4. `bin/build-game`, then confirm the new engine actually shipped: `grep -c Module.HEAPU8.set public/<env>_game_assets/*/dragonruby-wasm.js` (0 on 7.7+; nonzero = stale stub leaked). Load `/game`.
5. **Confirm the iframe loader patch still applies** (see below). If `bin/build-game` aborts with `Loader iframe guard not found`, the upgrade changed the loader — re-point the patch before continuing.

## iframe loader patch

We serve the game inside a same-origin `<iframe>` (`/game/frame` on `/play`). DragonRuby's HTML5 loader (`dragonruby-html5-loader.js`) hardcodes a guard that refuses to boot inside an iframe on Safari/Firefox — it swaps the frame for a `target='_top'` "Click Here to Load Game" link that escapes into the full window. `bin/build-game` neutralizes this after unzip by rewriting the guard's condition to `if (false)`, matching this exact line:

```js
if (isSafari() || isMobileSafari() || isAndroid() || isNestedIFrame() || isFirefox()) {
```

The patch **aborts the build** if that line is missing, so an upgrade that rewrites the loader fails loudly instead of silently reshipping the Safari-escapes-iframe bug. To fix after an upgrade:

1. Find the new guard in `game/.dragonruby/stubs/html5/dragonruby-html5-loader.js` — the block near the end (after `Module.setStatus('Downloading...')`) that sets `document.body.innerHTML` to a `Click Here to Load Game` link when `window.self !== window.top`.
2. Update the `guard` string in `bin/build-game` to match the new condition line so the `if (false)` rewrite lands again. Keep the abort so future drift stays loud.
3. Rebuild and confirm the shipped loader is patched: `grep -n "always boot inside our isolated iframe" public/<env>_game_assets/*/dragonruby-html5-loader.js` (present) and `grep -c "isSafari() || isMobileSafari()" ...` (0). Then load `/play` in **Safari** — the game must stay in the iframe, no full-window takeover.

## WASM bug history

7.x before 7.7 had a broken HTML5 `http_get` (`Module.HEAPU8` undefined, froze the tick loop at tick 0); we polyfilled it in `show.html.erb`. **7.7 fixed it** and the polyfill was removed. If a future upgrade regresses `http_get`, that's where a workaround goes.
