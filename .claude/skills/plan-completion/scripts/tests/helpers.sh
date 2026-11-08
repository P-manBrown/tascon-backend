# Helpers sourced by the test-*.sh files. Not a test file itself.
tests_dir=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
scripts_dir=$(dirname -- "$tests_dir")
. "$scripts_dir/lib/tempdir.sh"

# Tests run from lefthook's pre-commit too, where git exports variables that
# would point the temporary repositories at the real one.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_PREFIX GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES

failures=0
REPO=o/n
SHA=0123456789abcdef0123456789abcdef01234567

# check <name> <expected> <actual>
check() {
  if [ "$2" = "$3" ]; then
    printf 'ok   %s\n' "$1"
  else
    printf 'FAIL %s\n  expected: %s\n  actual:   %s\n' "$1" "$2" "$3"
    failures=$((failures + 1))
  fi
}

finish() {
  [ "$failures" -eq 0 ]
  exit $?
}

# new_case: fresh temporary directory, fake gh fixtures and log.
new_case() {
  [ -n "${case_dir:-}" ] && rm -rf "$case_dir"
  case_dir=$(make_temp_dir) || exit 1
  export FAKE_GH_DIR="$case_dir/fixtures" FAKE_GH_LOG="$case_dir/gh.log"
  mkdir "$FAKE_GH_DIR" "$case_dir/run"
  : >"$FAKE_GH_LOG"
}
trap '[ -n "${case_dir:-}" ] && rm -rf "$case_dir"' EXIT
export PATH="$tests_dir/fake-gh:$PATH"

key() { printf '%s' "$1" | tr '/?&=' '____'; }

# answer <endpoint> <body> [exit code]
answer() {
  printf '%s\n' "$2" >"$FAKE_GH_DIR/$(key "$1")"
  [ -n "${3:-}" ] && printf '%s\n' "$3" >"$FAKE_GH_DIR/$(key "$1").exit"
  return 0
}

pulls_endpoint() { printf 'repos/%s/pulls?state=%s&sort=created&direction=asc&per_page=100&page=%s' "$REPO" "$1" "$2"; }

# pr <number> <state> <merged_at or null> <base> <body>
pr() {
  jq -cn --argjson n "$1" --arg s "$2" --arg m "$3" --arg b "$4" --arg body "$5" \
    '{number: $n, state: $s, merged_at: (if $m == "null" then null else $m end), base: {ref: $b}, body: $body}'
}

# body <plan line>...: a pull request body whose Related Documents has the lines.
body() {
  printf '### Summary\n\nx\n\n### Related Documents\n\n'
  printf '%s\n' "$@"
  printf '\n### Notes (Optional)\n\nnone\n'
}

# repo_with_plans <plan name>...: main exists and active holds the plans.
repo_with_plans() {
  local items='[]' name
  answer "repos/$REPO/branches/main" "{\"name\":\"main\",\"commit\":{\"sha\":\"$SHA\"}}"
  for name in "$@"; do
    items=$(printf '%s' "$items" | jq -c --arg n "$name" '. + [{type: "file", name: $n}]')
  done
  answer "repos/$REPO/contents/.claude/plans/active?ref=$SHA" "$items"
}

# only_reads: every logged gh call is `api <endpoint>` (no method, no fields).
only_reads() {
  if grep -v -E '^api [^ ]+$' "$FAKE_GH_LOG" >/dev/null; then echo no; else echo yes; fi
}
