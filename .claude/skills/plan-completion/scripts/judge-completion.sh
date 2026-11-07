#!/usr/bin/env bash
# Usage: judge-completion.sh --repo <owner>/<name>
# Reads the repository through `gh api` only and prints one JSON object.
# Exit: 0 judged, nothing to fix / 4 judged, missing_marker or unreadable found /
#       3 GitHub queries incomplete / 2 usage error / 1 internal error
set -u

usage() {
  echo "usage: judge-completion.sh --repo <owner>/<name>" >&2
  exit 2
}

[ "$#" -eq 2 ] || usage
[ "$1" = "--repo" ] || usage
[[ "$2" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || usage

if ! command -v python3 >/dev/null 2>&1; then
  echo "judge-completion: python3 is not available" >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 -B "$script_dir/judge_completion.py" "$@"
