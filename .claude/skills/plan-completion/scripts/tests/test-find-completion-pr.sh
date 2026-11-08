#!/usr/bin/env bash
# Tests for find-completion-pr.sh with the fake gh.
set -u
. "$(dirname -- "${BASH_SOURCE[0]}")/helpers.sh"

CA=.claude/plans/completed/a.md
CB=.claude/plans/completed/b.md

run_find() {
  out=$(cd "$case_dir/run" && bash "$scripts_dir/find-completion-pr.sh" "$@" 2>"$case_dir/err")
  code=$?
}

open_page1() {
  answer "$(pulls_endpoint open 1)" "$(printf '%s\n' "$@" | jq -cs .)"
}

new_case
open_page1 "$(pr 20 open null main "$(body "- 🏃 Plan: $CA" '- ⬜ Spec: N/A')")" "$(pr 21 open null main "$(body "- 🏃 Plan: $CA")")"
run_find --repo "$REPO" --plan a
check "open completion pull requests: output" "$(printf '20\n21')" "$out"
check "open completion pull requests: exit" 0 "$code"
check "open completion pull requests: gh calls are reads" yes "$(only_reads)"
check "open completion pull requests: run directory stays empty" "" "$(ls -A "$case_dir/run")"

new_case
open_page1
run_find --repo "$REPO" --plan a
check "no open pull request: output" "" "$out"
check "no open pull request: exit" 0 "$code"

new_case
open_page1 "$(pr 20 closed null main "$(body "- 🏃 Plan: $CA")")"
run_find --repo "$REPO" --plan a
check "closed pull request is not counted" "" "$out"

new_case
open_page1 "$(pr 22 open null main "$(body "- 🏃 Plan: $CB")")"
run_find --repo "$REPO" --plan a
check "pull request for another plan: output" "" "$out"
check "pull request for another plan: exit" 0 "$code"

new_case
answer "$(pulls_endpoint open 1)" '{"message":"Server Error"}' 1
run_find --repo "$REPO" --plan a
check "query failure: exit" 3 "$code"
check "query failure: stdout" "" "$out"

new_case
run_find --repo "$REPO"
check "no --plan: exit" 2 "$code"
run_find --plan a
check "no --repo: exit" 2 "$code"
run_find --repo "$REPO" --plan a/b
check "plan name with a slash: exit" 2 "$code"

finish
