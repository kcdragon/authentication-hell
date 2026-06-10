#!/usr/bin/env bash
# Conductor workspace bootstrap.
#
# A new Conductor workspace is a fresh git worktree, and git worktrees do NOT
# inherit gitignored files. The Rails credential keys (config/master.key,
# config/credentials/*.key) and personal Conductor settings
# (.conductor/settings.local.toml) are gitignored, so without this step a new
# workspace can't decrypt credentials. Copy them from the repo root (the main
# checkout) into this workspace.
#
# Wired into scripts.setup in .conductor/settings.toml, ahead of bin/setup.
set -euo pipefail

root="${CONDUCTOR_ROOT_PATH:-}"

# Only seed local secrets on the user's Mac (skip cloud workspaces), and never
# copy onto the root checkout itself.
if [ "${CONDUCTOR_IS_LOCAL:-1}" != "1" ] || [ -z "$root" ] || [ "$root" = "$PWD" ]; then
  exit 0
fi

echo "== Seeding gitignored local files from $root =="

# Personal Conductor settings.
if [ -f "$root/.conductor/settings.local.toml" ]; then
  mkdir -p .conductor
  cp "$root/.conductor/settings.local.toml" .conductor/settings.local.toml
fi

# Rails credential keys (decrypt config/credentials*.yml.enc).
mkdir -p config
if [ -f "$root/config/master.key" ]; then
  cp "$root/config/master.key" config/master.key
fi
if [ -d "$root/config/credentials" ]; then
  mkdir -p config/credentials
  cp "$root"/config/credentials/*.key config/credentials/ 2>/dev/null || true
fi

# DragonRuby engine binaries + build stubs. These are gitignored per the engine's
# license, so a fresh git worktree doesn't inherit them — and without them
# bin/build-game can't package the /play bundle (dragonruby-publish needs the
# .dragonruby/ HTML5/WASM build stub). Seed them from the root checkout.
if [ -d "$root/game" ]; then
  for e in dragonruby dragonruby-publish .dragonruby; do
    if [ -e "$root/game/$e" ]; then
      rm -rf "game/$e"
      cp -R "$root/game/$e" "game/$e"
    fi
  done
fi
