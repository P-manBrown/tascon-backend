#!/usr/bin/env bash
set -uo pipefail

file_path=$(jq -r '.tool_input.file_path // empty')

case "$file_path" in
  *.rb|*.erb)
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    cd "$script_dir/../.." || exit 0
    bin/bundle exec rubocop --autocorrect --force-exclusion "$file_path" >&2
    ;;
esac

exit 0
