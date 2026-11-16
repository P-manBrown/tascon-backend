#!/usr/bin/env bash
set -u
. "$(dirname -- "${BASH_SOURCE[0]}")/helpers.sh"

# Success: main advanced, both branches restacked and pushed, HEAD back.
new_case
default_ls
advance_main m.txt m
sync_hook
restack_hook
before=$(head_state "$merge_wt")
run_restack "$merge_wt" --branch feat/b
check "success exit" 0 "$code"
check "success result" restacked "$(json result)"
check "success pr is null" null "$(json pr)"
check "success merged is empty" '[]' "$(jq -c .merged <<<"$out")"
check "repo sync without restack" yes "$(logged "$FAKE_GS_LOG" 'repo sync --restack=none')"
check "restacks from the top" yes "$(logged "$FAKE_GS_LOG" 'stack restack --branch feat/b')"
check "pushes feat/a" yes "$(logged "$FAKE_GS_LOG" 'branch submit --update-only --no-web --branch feat/a')"
check "pushes feat/b" yes "$(logged "$FAKE_GS_LOG" 'branch submit --update-only --no-web --branch feat/b')"
check "HEAD is back" "$before" "$(head_state "$merge_wt")"
check "feat/a is on main" 0 "$(git -C "$merge_wt" merge-base --is-ancestor main feat/a; echo $?)"

# A branch without a pull request is restacked but not pushed.
new_case
spice_ls \
  '{"name":"feat/a","down":{"name":"main"},"ups":[{"name":"feat/b"}],"change":{"id":"#1"},"push":{"ahead":0,"behind":0}}' \
  '{"name":"feat/b","down":{"name":"feat/a"}}' \
  '{"name":"main","ups":[{"name":"feat/a"}]}'
restack_hook
run_restack "$merge_wt" --branch feat/a
check "no-PR branch exit" 0 "$code"
check "no-PR branch not pushed" no "$(logged "$FAKE_GS_LOG" 'branch submit --update-only --no-web --branch feat/b')"

# Preconditions (23).
new_case
default_ls
printf 'x\n' >"$merge_wt/untracked.txt"
run_restack "$merge_wt" --branch feat/a
check "dirty tree" 23 "$code"
check "dirty tree names the file" yes "$([[ "$(json reason)" == *untracked.txt* ]] && echo yes)"
check "dirty tree does not sync" no "$(logged "$FAKE_GS_LOG" 'repo sync')"

new_case
default_ls
run_restack "$merge_wt" --branch feat/zzz
check "untracked branch" 23 "$code"

new_case
spice_ls \
  '{"name":"feat/a","down":{"name":"main"},"ups":[{"name":"feat/b"},{"name":"feat/c"}],"change":{"id":"#1"},"push":{"ahead":0,"behind":0}}' \
  '{"name":"feat/b","down":{"name":"feat/a"}}' '{"name":"feat/c","down":{"name":"feat/a"}}' \
  '{"name":"main","ups":[{"name":"feat/a"}]}'
run_restack "$merge_wt" --branch feat/b
check "branched stack" 23 "$code"

new_case
spice_ls \
  '{"name":"feat/a","down":{"name":"main"},"ups":[{"name":"feat/b"}],"change":{"id":"#1"},"push":{"ahead":1,"behind":0}}' \
  '{"name":"feat/b","down":{"name":"feat/a"},"change":{"id":"#2"},"push":{"ahead":0,"behind":0}}' \
  '{"name":"main","ups":[{"name":"feat/a"}]}'
run_restack "$merge_wt" --branch feat/b
check "local and remote differ" 23 "$code"
check "local and remote differ names the branch" yes "$([[ "$(json reason)" == *feat/a* ]] && echo yes)"

new_case
default_ls
git -C "$work" worktree add -q "$case_dir/held" feat/b
run_restack "$merge_wt" --branch feat/a
check "branch checked out in another worktree" 23 "$code"
check "held worktree is named" yes "$([[ "$(json reason)" == *"$case_dir/held"* ]] && echo yes)"

new_case
default_ls
git -C "$merge_wt" switch -q feat/a
run_restack "$merge_wt" --branch feat/a
check "running worktree has a stack branch" 23 "$code"

new_case
default_ls
restack_hook
git -C "$merge_wt" switch -q -c other
run_restack "$merge_wt" --branch feat/a
check "running worktree on an outside branch" 0 "$code"
check "outside branch is checked out again" "branch other" "$(head_state "$merge_wt")"

# Conflict (20): feat/a was restacked, feat/b conflicts; everything is undone.
new_case
default_ls
advance_main b.txt main-b
sync_hook
gs_hook stack_restack 'git switch -q feat/a && git rebase -q main && git update-ref refs/spice/data refs/heads/feat/a && git switch -q feat/b && git rebase -q feat/a'
gs_hook rebase_abort 'git rebase --abort'
before=$(head_state "$merge_wt")
run_restack "$merge_wt" --branch feat/b
check "conflict exit" 20 "$code"
check "conflict result" restack_conflict "$(json result)"
check "conflict names the branch" yes "$([[ "$(json reason)" == *feat/b* ]] && echo yes)"
check "rebase aborted" yes "$(logged "$FAKE_GS_LOG" 'rebase abort')"
check "feat/a restored" "$sha_a" "$(git -C "$merge_wt" rev-parse feat/a)"
check "feat/b restored" "$sha_b" "$(git -C "$merge_wt" rev-parse feat/b)"
check "spice data restored" "$sha_data" "$(git -C "$merge_wt" rev-parse refs/spice/data)"
check "conflict HEAD is back" "$before" "$(head_state "$merge_wt")"
check "conflict tree is clean" "" "$(git -C "$merge_wt" status --porcelain)"
check "conflict does not push" no "$(logged "$FAKE_GS_LOG" 'branch submit')"

# Push check (21): restack reports success but feat/a is not on main.
new_case
default_ls
advance_main m.txt m
sync_hook
gs_hook stack_restack 'exit 0'
run_restack "$merge_wt" --branch feat/b
check "push check exit" 21 "$code"
check "push check result" push_check_failed "$(json result)"
check "push check does not push" no "$(logged "$FAKE_GS_LOG" 'branch submit')"

# git-spice failure (3).
new_case
default_ls
printf '1\n' >"$FAKE_GS_DIR/repo_sync.exit"
run_restack "$merge_wt" --branch feat/a
check "sync failure" 3 "$code"

# Usage (23).
new_case
run_restack "$merge_wt"
check "usage" 23 "$code"

finish
