#!/usr/bin/env bash
# Tests for judge-completion.sh with the fake gh.
set -u
. "$(dirname -- "${BASH_SOURCE[0]}")/helpers.sh"

A=.claude/plans/active/a.md
B=.claude/plans/active/b.md
CA=.claude/plans/completed/a.md
EMPTY='{"completed":[],"missing_marker":[],"unreadable":[]}'
M1=2026-11-01T00:00:00Z
M2=2026-11-02T00:00:00Z

run_judge() {
  out=$(cd "$case_dir/run" && bash "$scripts_dir/judge-completion.sh" "$@" 2>"$case_dir/err")
  code=$?
}

# pulls_page1 <pr json>...: the only page of all pull requests.
pulls_page1() {
  answer "$(pulls_endpoint all 1)" "$(printf '%s\n' "$@" | jq -cs .)"
}

new_case
repo_with_plans a.md
pulls_page1
run_judge --repo "$REPO"
check "no pull requests: output" "$EMPTY" "$out"
check "no pull requests: exit" 0 "$code"

new_case
repo_with_plans a.md b.md
pulls_page1 "$(pr 10 closed $M1 main "$(body "- 🏃 Plan: $A")")" "$(pr 12 closed $M2 main "$(body "- ✅ Plan: $A")")"
run_judge --repo "$REPO"
check "completed: output" '{"completed":[{"plan":".claude/plans/active/a.md","prs":[10,12],"completing_pr":12}],"missing_marker":[],"unreadable":[]}' "$out"
check "completed: exit" 0 "$code"
check "completed: gh calls are reads" yes "$(only_reads)"
check "completed: run directory stays empty" "" "$(ls -A "$case_dir/run")"

new_case
repo_with_plans a.md
pulls_page1 "$(pr 10 closed $M1 main "$(body "- ✅ Plan: $A")")" "$(pr 13 open null main "$(body "- 🏃 Plan: $A")")"
run_judge --repo "$REPO"
check "open pull request: output" "$EMPTY" "$out"
check "open pull request: exit" 0 "$code"

new_case
repo_with_plans a.md
pulls_page1 "$(pr 10 closed $M1 main "$(body "- ✅ Plan: $A")")" "$(pr 11 closed null main "$(body "- 🏃 Plan: $A")")"
run_judge --repo "$REPO"
check "closed without merge: output" "$EMPTY" "$out"

new_case
repo_with_plans a.md
pulls_page1 "$(pr 10 closed $M1 feature "$(body "- ✅ Plan: $A")")"
run_judge --repo "$REPO"
check "merged into another branch: output" "$EMPTY" "$out"

new_case
repo_with_plans a.md
pulls_page1 "$(pr 10 closed $M1 main "$(body "- 🏃 Plan: $A")")" "$(pr 12 closed $M2 main "$(body "- 🏃 Plan: $A")")"
run_judge --repo "$REPO"
check "missing marker: output" '{"completed":[],"missing_marker":[{"plan":".claude/plans/active/a.md","prs":[10,12]}],"unreadable":[]}' "$out"
check "missing marker: exit" 4 "$code"

new_case
repo_with_plans a.md
pulls_page1 "$(pr 10 closed $M1 main "$(body "- ✅ Plan: $A")")" "$(pr 30 open null main "$(body "- ✅ Plan: $CA" '- ⬜ Spec: N/A')")"
run_judge --repo "$REPO"
check "open check-marked completion pull request: output" '{"completed":[{"plan":".claude/plans/active/a.md","prs":[10],"completing_pr":10}],"missing_marker":[],"unreadable":[]}' "$out"
check "open check-marked completion pull request: exit" 0 "$code"

new_case
repo_with_plans a.md
pulls_page1 "$(pr 10 closed $M1 main "$(body "- 🏃 Plan: $A")")" "$(pr 30 closed $M2 main "$(body "- ✅ Plan: $CA")")"
run_judge --repo "$REPO"
check "check mark on the completed plan path does not complete the active plan: output" '{"completed":[],"missing_marker":[{"plan":".claude/plans/active/a.md","prs":[10]}],"unreadable":[]}' "$out"
check "check mark on the completed plan path does not complete the active plan: exit" 4 "$code"

new_case
repo_with_plans
pulls_page1 "$(pr 10 closed $M1 main "$(body "- ✅ Plan: $A")")" "$(pr 30 closed $M2 main "$(body "- ✅ Plan: $CA")")"
run_judge --repo "$REPO"
check "plan already moved to completed: output" "$EMPTY" "$out"
check "plan already moved to completed: exit" 0 "$code"

new_case
repo_with_plans a.md b.md
pulls_page1 "$(pr 10 closed $M1 main "$(body "- ✅️ Plan: $A")")" "$(pr 11 closed $M1 main "$(body "- ✅ Plan: $B")")"
run_judge --repo "$REPO"
check "with and without U+FE0F: completed plans" '[".claude/plans/active/a.md",".claude/plans/active/b.md"]' "$(printf '%s' "$out" | jq -c '[.completed[].plan]')"

new_case
repo_with_plans a.md
pulls_page1 "$(pr 10 closed $M1 main "$(body "- 🏃 Plan: $A" "- ✅ Plan: $A")")"
run_judge --repo "$REPO"
check "check mark and another mark in one pull request: counted as completed" '[10]' "$(printf '%s' "$out" | jq -c '[.completed[].completing_pr]')"

new_case
repo_with_plans a.md
pulls_page1 "$(pr 10 closed $M2 main "$(body "- ✅ Plan: $A")")" "$(pr 12 closed $M1 main "$(body "- ✅ Plan: $A")")"
run_judge --repo "$REPO"
check "completing_pr is the latest merged check-marked pull request" 10 "$(printf '%s' "$out" | jq '.completed[0].completing_pr')"

new_case
repo_with_plans a.md
pulls_page1 "$(pr 20 open null main "$(printf '### Summary\n\nPlan: outside\n\n### Related Documents\n\n- ✅　Plan: %s\n- 🏃 Plan: %s \n- ⬜️ Plan: N/A\n- ⬜ Spec: N/A\n' "$A" "$A")")"
run_judge --repo "$REPO"
check "unreadable lines: output" '[{"pr":20,"line":"- ✅　Plan: .claude/plans/active/a.md"},{"pr":20,"line":"- 🏃 Plan: .claude/plans/active/a.md "}]' "$(printf '%s' "$out" | jq -c .unreadable)"
check "unreadable lines: exit" 4 "$code"

new_case
repo_with_plans a.md
pulls_page1 "$(pr 10 closed $M1 main "$(body "- 🏃 Plan: $A" '```' "- ✅ Plan: $A" "- ✅　Plan: broken" '```')")"
run_judge --repo "$REPO"
check "plan line in a code block is neither counted nor reported" '{"completed":[],"missing_marker":[{"plan":".claude/plans/active/a.md","prs":[10]}],"unreadable":[]}' "$out"

new_case
repo_with_plans a.md
pulls_page1 "$(pr 10 closed $M1 main "$(body '````' '```' '~~~~' '```` x' "- ✅ Plan: $A")")"
run_judge --repo "$REPO"
check "short, other-character or trailing-text fences do not close" "$EMPTY" "$out"

new_case
repo_with_plans a.md
pulls_page1 "$(pr 10 closed $M1 main "$(body '````' "- ✅ Plan: $B" '`````  ' "- ✅ Plan: $A")")"
run_judge --repo "$REPO"
check "a longer fence followed by spaces closes" '[".claude/plans/active/a.md"]' "$(printf '%s' "$out" | jq -c '[.completed[].plan]')"

new_case
repo_with_plans a.md
pulls_page1 "$(pr 10 closed $M1 main "$(printf '### Related Documents\r\n\r\n- ✅ Plan: %s\r\n- ⬜ Spec: N/A\r\n' "$A")")"
run_judge --repo "$REPO"
check "CRLF body: completed" '[".claude/plans/active/a.md"]' "$(printf '%s' "$out" | jq -c '[.completed[].plan]')"
check "CRLF body: exit" 0 "$code"

new_case
repo_with_plans a.md
answer "$(pulls_endpoint all 1)" "$(jq -cn --arg b "$(body '- ⬜ Plan: N/A')" '[range(1; 101) | {number: ., state: "closed", merged_at: null, base: {ref: "main"}, body: $b}]')"
answer "$(pulls_endpoint all 2)" "$(printf '%s\n' "$(pr 101 closed $M1 main "$(body "- ✅ Plan: $A")")" | jq -cs .)"
run_judge --repo "$REPO"
check "second page is read: completed" '[".claude/plans/active/a.md"]' "$(printf '%s' "$out" | jq -c '[.completed[].plan]')"
check "second page is read: no third page" 0 "$(grep -c 'page=3' "$FAKE_GH_LOG")"

new_case
repo_with_plans a.md
answer "$(pulls_endpoint all 1)" "$(jq -cn '[range(1; 101) | {number: ., state: "open", merged_at: null, base: {ref: "main"}, body: ""}]')"
answer "$(pulls_endpoint all 2)" '{"message":"Server Error"}' 1
run_judge --repo "$REPO"
check "failure on a later page: stdout" "" "$out"
check "failure on a later page: exit" 3 "$code"
check "failure on a later page: reason on stderr" yes "$([ -s "$case_dir/err" ] && echo yes || echo no)"

new_case
repo_with_plans a.md
answer "repos/$REPO/branches/main" '{"message":"Bad credentials","status":"401"}' 1
pulls_page1
run_judge --repo "$REPO"
check "branches failure: exit" 3 "$code"
check "branches failure: stdout" "" "$out"

new_case
repo_with_plans a.md
answer "repos/$REPO/branches/main" 'not json'
pulls_page1
run_judge --repo "$REPO"
check "branches not JSON: exit" 3 "$code"

new_case
repo_with_plans a.md
answer "repos/$REPO/contents/.claude/plans/active?ref=$SHA" '{"message":"Server Error","status":"500"}' 1
pulls_page1
run_judge --repo "$REPO"
check "contents failure: exit" 3 "$code"

new_case
answer "repos/$REPO/branches/main" "{\"name\":\"main\",\"commit\":{\"sha\":\"$SHA\"}}"
pulls_page1 "$(pr 10 closed $M1 main "$(body "- ✅ Plan: $A")")"
run_judge --repo "$REPO"
check "active is 404: no plans" "$EMPTY" "$out"
check "active is 404: exit" 0 "$code"

new_case
repo_with_plans a.md
answer "$(pulls_endpoint all 1)" 'not json'
run_judge --repo "$REPO"
check "pulls not JSON: exit" 3 "$code"

new_case
repo_with_plans a.md
answer "$(pulls_endpoint all 1)" '{"message":"Server Error"}' 1
run_judge --repo "$REPO"
check "pulls failure: exit" 3 "$code"

new_case
repo_with_plans a.md
answer "$(pulls_endpoint all 1)" '{"items":[]}'
run_judge --repo "$REPO"
check "pulls of the wrong shape: exit" 3 "$code"

new_case
run_judge
check "no --repo: exit" 2 "$code"
check "no --repo: stdout" "" "$out"
run_judge --repo foo
check "--repo without owner: exit" 2 "$code"
run_judge --repo "$REPO" extra
check "extra argument: exit" 2 "$code"
check "usage errors call no gh" 0 "$(wc -l <"$FAKE_GH_LOG" | tr -d ' ')"


new_case
pulls_page1
run_judge --repo "$REPO"
check "branches is 404: exit" 3 "$code"
check "branches is 404: stdout" "" "$out"
check "branches is 404: reason on stderr" yes "$([ -s "$case_dir/err" ] && echo yes || echo no)"

new_case
repo_with_plans a.md
run_judge --repo "$REPO"
check "pulls is 404: exit" 3 "$code"
check "pulls is 404: stdout" "" "$out"
check "pulls is 404: reason on stderr" yes "$([ -s "$case_dir/err" ] && echo yes || echo no)"

finish
