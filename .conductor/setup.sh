#!/usr/bin/env bash
# Conductor workspace bootstrap.
#
# A new Conductor workspace is a fresh git worktree, and git worktrees do NOT
# inherit gitignored files. The ones a workspace needs (Rails credential keys,
# personal Conductor settings, the DragonRuby engine binaries and build stubs)
# are listed in .worktreeinclude; `worktree include` copies them from the main
# checkout. `worktree new` already does this; Conductor workspaces need it here.
#
# Wired into scripts.setup in .conductor/settings.toml, ahead of bin/setup.
set -euo pipefail

root="${CONDUCTOR_ROOT_PATH:-}"

# Only seed local files on the user's Mac (skip cloud workspaces), and never
# onto the root checkout itself.
if [ "${CONDUCTOR_IS_LOCAL:-1}" != "1" ] || [ -z "$root" ] || [ "$root" = "$PWD" ]; then
  exit 0
fi

worktree="$(command -v worktree || echo "$HOME/.local/bin/worktree")"
if ! { [ -x "$worktree" ] && "$worktree" include; }; then
  echo "== Couldn't copy the files .worktreeinclude lists; run bin/install-tools in factory-tools to update worktree, or copy them by hand =="
fi

# Draft levels from the in-game editor are shared across every workspace:
# the real (gitignored) directory lives in the root checkout, each worktree
# gets a symlink to it. Promoted levels live in the committed
# game/mygame/data/levels/ and need no seeding.
mkdir -p "$root/level_drafts"
if [ ! -e level_drafts ]; then
  ln -s "$root/level_drafts" level_drafts
fi
