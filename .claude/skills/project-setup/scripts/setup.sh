#!/usr/bin/env bash
# Prepare this repository. On Linux, install the gems with bundle (bundle
# check, then bundle install when gems are missing). On other OSes, do nothing
# and exit 0.
# Usage:
#   setup.sh              manual run: use the git repository of the current directory
#   setup.sh --from-hook  hook run: read the hook input JSON from stdin and use its cwd
# Stdout stays empty on success (hook stdout enters the conversation).
# The location is never derived from this script's path or CLAUDE_PROJECT_DIR
# (inside a worktree both point to the main checkout).
set -euo pipefail

if [ "$(uname -s)" != "Linux" ]; then
  exit 0
fi

if [ "${1:-}" = "--from-hook" ]; then
  if ! cwd="$(jq -r '.cwd // empty')" || [ -z "$cwd" ]; then
    echo "project-setup: cannot read cwd from the hook input"
    exit 1
  fi
else
  cwd="$PWD"
fi

if ! root="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)"; then
  echo "project-setup: not a git repository: $cwd"
  exit 1
fi
cd "$root"

if ! { bundle check || bundle install; } >&2; then
  echo "project-setup: bundle install failed (see stderr)"
  exit 1
fi
