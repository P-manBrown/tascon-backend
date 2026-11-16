#!/usr/bin/env bash
set -u
. "$(dirname -- "${BASH_SOURCE[0]}")/helpers.sh"

# expect <name> <exit code> <result>
expect() {
  check "$1: exit" "$2" "$code"
  check "$1: result" "$3" "$(json result)"
  check "$1: exit field" "$2" "$(json exit)"
}

# --- where it runs (REQ-001) ---
new_case
two_prs
git -C "$merge_wt" switch -q -c somewhere
run_merge
expect "HEAD on a branch" 23 precondition_failed
check "HEAD on a branch: no gh" "" "$(<"$FAKE_GH_LOG")"

new_case
two_prs
git -C "$merge_wt" switch -q --detach feat/a
run_merge
expect "HEAD not an ancestor of origin/main" 23 precondition_failed
check "not an ancestor: no gh" "" "$(<"$FAKE_GH_LOG")"

new_case
two_prs
printf 'changed\n' >>"$merge_wt/f.txt"
run_merge
expect "tracked change" 23 precondition_failed
check "tracked change: no gh" "" "$(<"$FAKE_GH_LOG")"
check "tracked change: names the file" yes "$([[ "$(json reason)" == *f.txt* ]] && echo yes)"

new_case
two_prs
printf 'x\n' >"$merge_wt/new.txt"
run_merge
expect "untracked file" 23 precondition_failed
check "untracked file: no gh" "" "$(<"$FAKE_GH_LOG")"

new_case
two_prs
git -C "$merge_wt" switch -q --detach HEAD~1
run_merge
check "older main commit passes the place check" yes "$(gh_called 'repo view')"

new_case
run_merge --pr x
expect "usage" 23 precondition_failed
check "usage: pr is null" null "$(json pr)"

# --- range (REQ-002) ---
new_case
two_prs '.isDraft = true'
run_merge
expect "bottom is a draft" 10 wait
check "draft: waiting_on" 1 "$(json waiting_on)"
check "draft: no merge request" no "$(gh_called merge-async)"

new_case
two_prs '.statusCheckRollup[0].status = "IN_PROGRESS" | .statusCheckRollup[0].conclusion = null'
run_merge
expect "checks running" 10 wait

new_case
two_prs '.statusCheckRollup += [{__typename: "StatusContext", context: "ci/x", state: "PENDING"}]'
run_merge
expect "status context pending" 10 wait

new_case
two_prs '.reviewDecision = "REVIEW_REQUIRED"'
run_merge
expect "bottom not approved" 10 wait

new_case
two_prs '.' '.reviewDecision = "REVIEW_REQUIRED"'
run_merge
check "lower part is the range: not waiting" no "$([ "$(json result)" = wait ] && echo yes || echo no)"
check "lower part is the range: reads #2" yes "$(gh_called 'pr view 2')"

new_case
answer repo-view '{"nameWithOwner":"o/n"}'
answer GET_repos_o_n_stacks_pull_request_1 '{"message":"Not Found","status":"404"}' 1
answer pr-view-1 "$(pr_json 1 feat/a main "$sha_a" '.isDraft = true')"
default_ls
run_merge --pr 1
expect "404 stacks means one pull request" 10 wait
check "404 stacks: waiting_on" 1 "$(json waiting_on)"

new_case
answer repo-view '{"nameWithOwner":"o/n"}'
answer GET_repos_o_n_stacks_pull_request_1 'oops' 1
run_merge --pr 1
expect "stacks read failure" 3 transient

# --- order and worktrees (REQ-003) ---
new_case
two_prs '.' '.baseRefName = "main"'
run_merge
expect "wrong base" 23 precondition_failed
check "wrong base: names #2" yes "$([[ "$(json reason)" == *"#2"* ]] && echo yes)"

new_case
two_prs
git -C "$work" worktree add -q "$case_dir/held" feat/a
run_merge
expect "stack branch checked out" 23 precondition_failed
check "checked out: no merge request" no "$(gh_called merge-async)"

new_case
two_prs
spice_ls \
  '{"name":"feat/a","down":{"name":"main"},"ups":[{"name":"feat/b"}],"change":{"id":"#1"},"push":{"ahead":0,"behind":0}}' \
  '{"name":"feat/b","down":{"name":"feat/a"},"ups":[{"name":"feat/c"}],"change":{"id":"#2"},"push":{"ahead":0,"behind":0}}' \
  '{"name":"feat/c","down":{"name":"feat/b"}}' \
  '{"name":"main","ups":[{"name":"feat/a"}]}'
git -C "$work" branch -q feat/c feat/b
git -C "$work" worktree add -q "$case_dir/held" feat/c
run_merge
expect "branch above the stack checked out" 23 precondition_failed

# --- stale (REQ-004) ---
new_case
two_prs '.mergeStateStatus = "BEHIND"'
restack_hook
run_merge
expect "behind restacks" 10 restacked
check "behind: pr is ours" 2 "$(json pr)"
check "behind: restack ran" yes "$(logged "$FAKE_GS_LOG" 'stack restack --branch feat/b')"
check "behind: no merge request" no "$(gh_called merge-async)"
check "behind: no pre-merge check" "" "$(<"$FAKE_CHECK_LOG")"
check "behind: HEAD still detached" yes "$([[ "$(head_state "$merge_wt")" == detached* ]] && echo yes)"
check "behind: one JSON line" 1 "$(printf '%s\n' "$out" | jq -s length)"

new_case
two_prs
advance_main m.txt m
restack_hook
sync_hook
git -C "$merge_wt" fetch -q origin
git -C "$merge_wt" switch -q --detach origin/main
run_merge
expect "head not on origin/main restacks" 10 restacked

new_case
two_prs '.mergeStateStatus = "BEHIND"'
advance_main b.txt main-b
sync_hook
gs_hook stack_restack 'git switch -q feat/a && git rebase -q main && git switch -q feat/b && git rebase -q feat/a'
gs_hook rebase_abort 'git rebase --abort'
git -C "$merge_wt" fetch -q origin
git -C "$merge_wt" switch -q --detach origin/main
run_merge
expect "restack conflict passes through" 20 restack_conflict

new_case
two_prs '.mergeStateStatus = "BEHIND"'
advance_main m.txt m
sync_hook
gs_hook stack_restack 'exit 0'
git -C "$merge_wt" fetch -q origin
git -C "$merge_wt" switch -q --detach origin/main
run_merge
expect "push check passes through" 21 push_check_failed

finish
