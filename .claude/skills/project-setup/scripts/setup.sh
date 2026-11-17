#!/usr/bin/env bash
# Configure git-spice for the repository and install project dependencies.
# The git-spice settings are written on every OS; dependencies are installed
# on Linux only.
# Usage:
#   setup.sh              manual run: use the git repository of the current directory
#   setup.sh --from-hook  hook run: read the hook input JSON from stdin and use its cwd
# Stdout stays empty on success (hook stdout enters the conversation).
# The location is never derived from this script's path or CLAUDE_PROJECT_DIR
# (inside a worktree both point to the main checkout).
set -euo pipefail

if [ "${1:-}" = "--from-hook" ]; then
  if ! cwd="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["cwd"])')"; then
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

# Native GitHub stacks and the merge commands of git-spice, merging by squash.
# A value that is already set is not written again.
for setting in spice.forge.github.stacks=true spice.experiment.merge=true spice.merge.method=squash; do
  key=${setting%%=*}
  value=${setting#*=}
  [ "$(git config --local --get "$key" || true)" = "$value" ] && continue
  if ! git config --local "$key" "$value" >&2; then
    echo "project-setup: cannot set $key=$value in the git config (see stderr)"
    exit 1
  fi
done

if [ "$(uname -s)" != "Linux" ]; then
  exit 0
fi

if ! { bundle check || bundle install; } >&2; then
  echo "project-setup: bundle install failed (see stderr)"
  exit 1
fi
