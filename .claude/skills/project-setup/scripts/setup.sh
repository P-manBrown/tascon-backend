#!/usr/bin/env bash
# Install project dependencies. Linux only; no-op elsewhere.
# Stdout stays empty on success (SessionStart hook stdout enters the conversation).
set -euo pipefail

if [ "$(uname -s)" != "Linux" ]; then
  exit 0
fi

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$root"

if ! { bundle check || bundle install; } >&2; then
  echo "project-setup: bundle install failed (see stderr)"
  exit 1
fi
