#!/usr/bin/env bash
set -u
. "$(dirname -- "${BASH_SOURCE[0]}")/helpers.sh"

# expect <name> <exit code> <result>
expect() {
  check "$1: exit" "$2" "$code"
  check "$1: result" "$3" "$(json result)"
  check "$1: exit field" "$2" "$(json exit)"
}

# --- fail closed on an unreadable pull request ---
new_case
two_prs '.statusCheckRollup = ["weird"]'
run_merge
expect "unreadable checks" 3 transient
check "unreadable checks: stops before the end" "" "$([[ "$(json reason)" == *まだ作っていない* ]] && echo yes)"

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

# --- plan-completing pull requests (REQ-005) ---
# done_body <testing text> [notes text]: a body with a ✅ Plan line.
done_body() {
  printf '### Summary\n\nx\n\n### Related Documents\n\n- ✅ Plan: .claude/plans/p.md\n\n### Testing\n\n%s\n\n### Notes (Optional)\n\n%s\n' \
    "$1" "${2:-none}"
}
# with_body <body>: a jq update that sets the body.
with_body() { printf '.body = %s' "$(jq -cn --arg b "$1" '$b')"; }

new_case
two_prs '.' "$(with_body "$(done_body "judged at 0000000aaaaaaa")")"
run_merge
expect "✅ without the head" 23 precondition_failed
check "✅ without the head: reason" "PR #2 の Testing に head ${sha_b:0:7} で判定した記録が無い" "$(json reason)"
check "✅ without the head: no merge request" no "$(gh_called merge-async)"

new_case
two_prs '.' "$(with_body "$(done_body "judged at $sha_b")")"
run_merge
check "✅ with 40 digits passes" no "$([ "$(json result)" = precondition_failed ] && echo yes || echo no)"

new_case
two_prs '.' "$(with_body "$(done_body "judged at ${sha_b:0:7}")")"
run_merge
check "✅ with 7 digits passes" no "$([ "$(json result)" = precondition_failed ] && echo yes || echo no)"

new_case
two_prs '.' "$(with_body "$(done_body "judged at ${sha_a}")")"
run_merge
expect "✅ with an old head only" 23 precondition_failed

new_case
two_prs '.' "$(with_body "$(done_body "none" "judged at $sha_b")")"
run_merge
expect "✅ head only in Notes" 23 precondition_failed

new_case
two_prs '.' "$(with_body "$(done_body $'```\n'"$sha_b"$'\n```')")"
run_merge
expect "✅ head only in a fence" 23 precondition_failed

new_case
two_prs '.' "$(with_body $'### Related Documents\n\n- Plan: .claude/plans/p.md\n\n### Testing\n\nnone')"
run_merge
check "no ✅: Testing not read" no "$([ "$(json result)" = precondition_failed ] && echo yes || echo no)"

new_case
two_prs "$(with_body $'### Related Documents\n\n- Plan:.claude/plans/p.md')"
run_merge
expect "unreadable Plan line" 23 precondition_failed
check "unreadable Plan line: names #1" yes "$([[ "$(json reason)" == *"#1"* ]] && echo yes)"

new_case
two_prs '.mergeStateStatus = "BEHIND"' "$(with_body "$(done_body "none")")"
restack_hook
run_merge
expect "✅ behind restacks first" 10 restacked

# --- pre-merge check (REQ-006) ---
checks_dir() { printf '%s/pre-merge-checks' "$(git -C "$merge_wt" rev-parse --path-format=absolute --git-common-dir)"; }

new_case
two_prs
before=$(git -C "$merge_wt" rev-parse HEAD)
run_merge
check "pass: ran at the top head" "$sha_b" "$(<"$FAKE_CHECK_LOG")"
check "pass: recorded" pass "$(<"$(checks_dir)/$sha_b")"
check "pass: log kept" yes "$([ -f "$(checks_dir)/$sha_b.log" ] && echo yes)"
check "pass: HEAD back" "detached $before" "$(head_state "$merge_wt")"
check "pass: tree clean" "" "$(git -C "$merge_wt" status --porcelain)"
: >"$FAKE_CHECK_LOG"
run_merge
check "pass: not run again" "" "$(<"$FAKE_CHECK_LOG")"

new_case
two_prs
export FAKE_CHECK_EXIT=1
before=$(git -C "$merge_wt" rev-parse HEAD)
run_merge
expect "fail" 22 pre_merge_check_failed
check "fail: recorded" fail "$(<"$(checks_dir)/$sha_b")"
check "fail: reason has the record" yes "$([[ "$(json reason)" == *"$(checks_dir)/$sha_b"* ]] && echo yes)"
check "fail: HEAD back" "detached $before" "$(head_state "$merge_wt")"
check "fail: no merge request" no "$(gh_called merge-async)"
: >"$FAKE_CHECK_LOG"
unset FAKE_CHECK_EXIT
run_merge
expect "fail record kept" 22 pre_merge_check_failed
check "fail record: not run again" "" "$(<"$FAKE_CHECK_LOG")"
rm -f "$(checks_dir)/$sha_b" "$(checks_dir)/$sha_b.log"
run_merge
check "deleted record: runs again" "$sha_b" "$(<"$FAKE_CHECK_LOG")"

new_case
two_prs
export FAKE_CHECK_EXIT=2
run_merge
expect "exit 2 is a failure" 22 pre_merge_check_failed
check "exit 2: recorded fail" fail "$(<"$(checks_dir)/$sha_b")"
unset FAKE_CHECK_EXIT

new_case
two_prs
export FAKE_CHECK_TOUCH="$merge_wt/b.txt"
before=$(git -C "$merge_wt" rev-parse HEAD)
run_merge
expect "check changed a tracked file" 23 precondition_failed
check "changed file: no merge request" no "$(gh_called merge-async)"
check "changed file: reason names the file" yes "$([[ "$(json reason)" == *b.txt* ]] && echo yes)"
check "changed file: reason names the commit" yes "$([[ "$(json reason)" == *"$before"* ]] && echo yes)"
unset FAKE_CHECK_TOUCH

new_case
two_prs
mkdir -p "$(checks_dir)"
printf 'x\n' >"$(checks_dir)/$sha_b"
run_merge
expect "unknown record content" 23 precondition_failed

new_case
two_prs
run_merge
check "the check next to merge-stack.sh ran" yes "$([ -s "$FAKE_CHECK_LOG" ] && echo yes)"
check "copies are removed" "" "$(ls -A "$case_dir/tmp")"

# --- merge (REQ-007, REQ-008, REQ-016) ---
put_key=PUT_repos_o_n_pulls_2_merge-async
get_key=GET_repos_o_n_pulls_2_merge-async_u1

# include <status line> <body>: a `gh api --include` answer.
include() { printf '%s\nContent-Type: application/json\n\n%s' "$1" "$2"; }

# github_merged: GitHub deleted the merged heads (done before the run, since
# the script fetches with --prune after the merge).
github_merged() { git -C "$remote" branch -q -D "$@"; }

# sync_deletes <branch>...: `git-spice repo sync` deletes the local branches.
sync_deletes() { gs_hook repo_sync "git branch -q -D $*"; }

no_forbidden_calls() {
  check "$1: no gh pr merge" no "$(gh_called 'pr merge')"
  check "$1: no gh stack" no "$(gh_called 'stack ')"
  check "$1: no git-spice merge" no "$(logged "$FAKE_GS_LOG" merge)"
  check "$1: no submit" no "$(logged "$FAKE_GS_LOG" submit)"
  check "$1: no push" no "$(logged "$FAKE_GS_LOG" push)"
}

new_case
two_prs
answer "$put_key" "$(include 'HTTP/2.0 202 Accepted' '{"status":"pending","details":{"uuid":"u1"}}')"
answer "$get_key.1" '{"status":"pending","details":{"uuid":"u1"}}'
answer "$get_key.2" '{"status":"merged","details":{"sha":"abc"}}'
github_merged feat/a feat/b
sync_deletes feat/a feat/b
run_merge
expect "202 pending merged" 0 merged
check "merged numbers" '[1,2]' "$(jq -c .merged <<<"$out")"
check "one PUT to the top" yes "$(gh_called "api --include --method PUT -H X-GitHub-Api-Version: 2026-03-10 repos/o/n/pulls/2/merge-async -f sha=$sha_b -f merge_method=squash -f merge_action=direct_merge")"
check "polled twice" 2 "$(<"$FAKE_GH_DIR/$get_key.count")"
check "repo sync without restack" yes "$(logged "$FAKE_GS_LOG" 'repo sync --restack=none')"
no_forbidden_calls "202 pending merged"

new_case
two_prs
answer "$put_key" "$(include 'HTTP/2.0 200 OK' '{"status":"merged","details":{"sha":"abc"}}')"
github_merged feat/a feat/b
sync_deletes feat/a feat/b
run_merge
expect "200 already merged" 0 merged

new_case
two_prs
answer "$put_key" "$(include 'HTTP/2.0 202 Accepted' '{"status":"pending","details":{"uuid":"u1"}}')"
answer "$get_key" '{"status":"failed","details":{"message":"Merge conflict"}}'
run_merge
expect "failed" 24 merge_rejected
check "failed: reason has the message" yes "$([[ "$(json reason)" == *"Merge conflict"* ]] && echo yes)"

new_case
two_prs
answer "$put_key" "$(include 'HTTP/2.0 409 Conflict' '{"status":"pending","details":{"uuid":"u1"}}')" 1
answer "$get_key" '{"status":"merged","details":{}}'
github_merged feat/a feat/b
sync_deletes feat/a feat/b
run_merge
expect "409 polls the existing request" 0 merged

new_case
two_prs
answer "$put_key" "$(include 'HTTP/2.0 409 Conflict' '{"message":"exists"}')" 1
run_merge
expect "409 without a UUID" 3 transient

new_case
two_prs
answer "$put_key" "$(include 'HTTP/2.0 202 Accepted' '{"status":"pending","details":{"uuid":"u1"}}')"
answer "$get_key" '{"status":"pending","details":{"uuid":"u1"}}'
run_merge
expect "poll timeout" 3 transient

for status in 400 422; do
  new_case
  two_prs
  answer "$put_key" "$(include "HTTP/2.0 $status Bad" '{"message":"not mergeable"}')" 1
  run_merge
  expect "HTTP $status" 24 merge_rejected
done

new_case
two_prs
answer "$put_key" "$(include 'HTTP/2.0 502 Bad Gateway' '{"message":"oops"}')" 1
run_merge
expect "HTTP 502" 3 transient

new_case
two_prs
answer "$put_key" 'connection reset' 1
run_merge
expect "no status line" 3 transient

new_case
two_prs
answer "$put_key" "$(include 'HTTP/2.0 202 Accepted' '{"status":"pending","details":{"uuid":"u1"}}')"
answer "$get_key" '{"status":"merged","details":{}}'
sync_deletes feat/a
run_merge
expect "merged branch left" 23 precondition_failed
check "merged branch left: merged numbers" '[1,2]' "$(jq -c .merged <<<"$out")"
check "merged branch left: names feat/b" yes "$([[ "$(json reason)" == *feat/b* ]] && echo yes)"

new_case
two_prs
cat >"$FAKE_GS_DIR/ls.sh" <<EOF
n=\$(cat '$FAKE_GS_DIR/ls.count' 2>/dev/null || echo 0)
n=\$((n + 1))
echo "\$n" >'$FAKE_GS_DIR/ls.count'
[ "\$n" -eq 2 ] && git worktree add -q '$case_dir/late' feat/a >/dev/null 2>&1
cat '$FAKE_GS_DIR/ls'
EOF
answer "$put_key" "$(include 'HTTP/2.0 202 Accepted' '{"status":"pending","details":{"uuid":"u1"}}')"
run_merge
expect "worktree check again before merging" 23 precondition_failed
check "late worktree: checked twice" 2 "$(<"$FAKE_GS_DIR/ls.count")"
check "late worktree: pre-merge check ran" "$sha_b" "$(<"$FAKE_CHECK_LOG")"
check "late worktree: no merge request" no "$(gh_called merge-async)"

# sync_retargets_feat_b: `git-spice repo sync` deletes the local feat/a and
# git-spice then lists feat/b on main.
sync_retargets_feat_b() {
  cat >"$FAKE_GS_DIR/ls.after" <<'EOF'
{"name":"feat/b","down":{"name":"main"},"change":{"id":"#2"},"push":{"ahead":0,"behind":0}}
{"name":"main","ups":[{"name":"feat/b"}]}
EOF
  gs_hook repo_sync "git branch -q -D feat/a && cp '$FAKE_GS_DIR/ls.after' '$FAKE_GS_DIR/ls'"
}

# Partial merge: #2 is not approved, #1 is merged; GitHub restacked feat/b.
new_case
answer repo-view '{"nameWithOwner":"o/n"}'
stack_answer 1 1 2
answer pr-view-1 "$(pr_json 1 feat/a main "$sha_a")"
answer pr-view-2 "$(pr_json 2 feat/b feat/a "$sha_b" '.reviewDecision = "REVIEW_REQUIRED"')"
default_ls
answer PUT_repos_o_n_pulls_1_merge-async "$(include 'HTTP/2.0 202 Accepted' '{"status":"pending","details":{"uuid":"u1"}}')"
answer GET_repos_o_n_pulls_1_merge-async_u1 '{"status":"merged","details":{}}'
git -C "$work" switch -q -c rebased main
printf 'b\n' >"$work/b.txt"
git -C "$work" add b.txt
git -C "$work" commit -q -m "b rebased"
git -C "$work" push -q -f origin rebased:feat/b
git -C "$work" switch -q main
rebased=$(git -C "$work" rev-parse rebased)
github_merged feat/a
sync_retargets_feat_b
run_merge --pr 1
expect "partial merge" 0 merged
check "partial merge: merged numbers" '[1]' "$(jq -c .merged <<<"$out")"
check "partial merge: feat/b follows GitHub" "$rebased" "$(git -C "$merge_wt" rev-parse feat/b)"
check "partial merge: no upstream config added" "" "$(git -C "$merge_wt" config --get branch.feat/b.merge)"
check "partial merge: checks ran at #1" "$sha_a" "$(<"$FAKE_CHECK_LOG")"

# Rerun after cleanup stopped: #1 is already MERGED at the bottom.
new_case
answer repo-view '{"nameWithOwner":"o/n"}'
stack_answer 2 1 2
answer pr-view-1 "$(pr_json 1 feat/a main "$sha_a" '.state = "MERGED"')"
answer pr-view-2 "$(pr_json 2 feat/b feat/a "$sha_b")"
default_ls
github_merged feat/a
sync_retargets_feat_b
run_merge
expect "merged bottom is cleaned up" 0 merged
check "merged bottom: merged numbers" '[1]' "$(jq -c .merged <<<"$out")"
check "merged bottom: no merge request" no "$(gh_called merge-async)"
check "merged bottom: no pre-merge check" "" "$(<"$FAKE_CHECK_LOG")"

# The cleanup is done, #1 stays MERGED in the stack: the rerun goes on with #2.
answer pr-view-2 "$(pr_json 2 feat/b main "$sha_b")"
answer "$put_key" "$(include 'HTTP/2.0 200 OK' '{"merged":true}')"
github_merged feat/b
sync_deletes feat/b
run_merge
expect "merged bottom, second run merges #2" 0 merged
check "second run: merged numbers" '[2]' "$(jq -c .merged <<<"$out")"
check "second run: merge requested" yes "$(gh_called 'merge-async')"

finish
