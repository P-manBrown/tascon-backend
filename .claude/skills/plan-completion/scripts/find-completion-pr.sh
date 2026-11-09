#!/usr/bin/env bash
# Usage: find-completion-pr.sh --repo <owner>/<name> --plan <name>
# Prints, one per line in ascending order, the numbers of the open pull
# requests whose Related Documents has a plan line pointing at
# .claude/plans/completed/<name>.md (any mark). Prints nothing when none.
# Exit: 0 checked / 3 GitHub queries incomplete / 2 usage error / 1 internal error
set -u

script_dir=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd) || exit 1
lib_dir="$script_dir/lib"
. "$lib_dir/github.sh" || exit 1

usage() {
  printf '%s\n' "usage: find-completion-pr.sh --repo <owner>/<name> --plan <name>" >&2
  exit 2
}

repo=""
plan=""
while [ $# -gt 0 ]; do
  case "$1" in
    --repo)
      [ $# -ge 2 ] && [ -z "$repo" ] || usage
      repo=$2
      shift 2
      ;;
    --plan)
      [ $# -ge 2 ] && [ -z "$plan" ] || usage
      plan=$2
      shift 2
      ;;
    *) usage ;;
  esac
done
[[ "$repo" =~ ^[[:alnum:]_.-]+/[[:alnum:]_.-]+$ ]] || usage
[[ "$plan" =~ ^[[:alnum:]_.-]+$ ]] || usage
command -v jq >/dev/null 2>&1 || { printf '%s\n' "jq is not installed" >&2; exit 1; }

pages=$(gh_pull_pages "$repo" open) || exit 3

printf '%s\n' "$pages" | jq -r -n -L "$lib_dir" --arg path ".claude/plans/completed/$plan.md" '
  include "markdown";
  [inputs] | add // [] | unique_by(.number)
  | .[] | select(.state == "open") | select(any(.body | plan_lines[]; .path == $path)) | .number' \
  || { printf '%s\n' "failed to read the pull requests" >&2; exit 1; }
