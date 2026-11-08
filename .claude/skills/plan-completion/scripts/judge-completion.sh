#!/usr/bin/env bash
# Usage: judge-completion.sh --repo <owner>/<name>
# Judges which plans in .claude/plans/active/ on main are completed, reading
# GitHub through `gh api` only. Writes nothing to the working directory.
# Output (stdout, exit 0 or 4 only):
#   {"completed": [{"plan", "prs", "completing_pr"}],
#    "missing_marker": [{"plan", "prs"}], "unreadable": [{"pr", "line"}]}
# Exit: 0 judged, nothing to report / 4 judged, missing_marker or unreadable
#       found / 3 GitHub queries incomplete / 2 usage error / 1 internal error
set -u

script_dir=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd) || exit 1
lib_dir="$script_dir/lib"
. "$lib_dir/github.sh" || exit 1

usage() {
  printf '%s\n' "usage: judge-completion.sh --repo <owner>/<name>" >&2
  exit 2
}

repo=""
while [ $# -gt 0 ]; do
  case "$1" in
    --repo)
      [ $# -ge 2 ] && [ -z "$repo" ] || usage
      repo=$2
      shift 2
      ;;
    *) usage ;;
  esac
done
[[ "$repo" =~ ^[[:alnum:]_.-]+/[[:alnum:]_.-]+$ ]] || usage
command -v jq >/dev/null 2>&1 || { printf '%s\n' "jq is not installed" >&2; exit 1; }

main_json=$(gh_read "repos/$repo/branches/main")
case $? in
  0) ;;
  4)
    printf '%s\n' "branches/main of $repo was not found (check the repository name and access)" >&2
    exit 3
    ;;
  *) exit 3 ;;
esac
sha=$(printf '%s' "$main_json" | jq -r '.commit.sha // empty' 2>/dev/null)
[[ "$sha" =~ ^[0-9a-f]{40}$ ]] || { printf '%s\n' "branches/main has no commit sha" >&2; exit 3; }

contents=$(gh_read "repos/$repo/contents/.claude/plans/active?ref=$sha")
case $? in
  0) ;;
  4) contents='[]' ;;
  *) exit 3 ;;
esac
plans=$(printf '%s' "$contents" | jq -c '
  if type == "array"
  then [.[] | select(.type == "file" and (.name | endswith(".md"))) | ".claude/plans/active/" + .name] | sort
  else error("unexpected shape")
  end' 2>/dev/null) || { printf '%s\n' "contents of .claude/plans/active has an unexpected shape" >&2; exit 3; }

pages=$(gh_pull_pages "$repo" all) || exit 3

result=$(printf '%s\n%s\n' "$plans" "$pages" | jq -c -n -L "$lib_dir" '
  include "markdown";
  input as $plans
  | ([inputs] | add // [] | unique_by(.number)) as $prs
  | ($prs | map({key: (.number | tostring), value: .}) | from_entries) as $by_number
  | [$prs[] | .number as $n | .body | plan_lines[] | {pr: $n, mark, path}] as $refs
  | [$prs[] | .number as $n | .body | unreadable_lines[] | {pr: $n, line: .}] as $unreadable
  | [$plans[] as $plan
     | [$refs[] | select(.path == $plan)] as $r
     | ($r | map(.pr) | unique) as $s
     | select(($s | length) > 0)
     | select(all($s[]; $by_number[tostring] | .merged_at != null and .base == "main"))
     | {plan: $plan, prs: $s, done: ($r | map(select(.mark == "✅") | .pr) | unique)}] as $judged
  | {completed: [$judged[] | select((.done | length) > 0)
                 | {plan, prs, completing_pr: ([.done[] | $by_number[tostring]] | max_by(.merged_at) | .number)}],
     missing_marker: [$judged[] | select((.done | length) == 0) | {plan, prs}],
     unreadable: ($unreadable | sort_by(.pr, .line))}') || { printf '%s\n' "failed to judge the pull requests" >&2; exit 1; }

printf '%s\n' "$result"
if printf '%s' "$result" | jq -e '(.missing_marker | length) == 0 and (.unreadable | length) == 0' >/dev/null; then
  exit 0
fi
exit 4
