#!/usr/bin/env bash
# Usage: merge-stack.sh --pr <number>
# Merges the stack that contains the pull request from the bottom up to the
# highest pull request that is approved and passing its checks, with one
# asynchronous merge request. Run it in a worktree whose HEAD is detached at
# origin/main (or an older main commit) and whose tree is clean.
# Output (stdout): one JSON line
#   {"result", "exit", "pr", "merged", "waiting_on", "reason"}
# Exit: 0 merged / 10 wait or restacked / 20 restack conflict / 21 push check
#       failed / 22 pre-merge check failed / 23 precondition failed /
#       24 merge rejected / 3 transient failure
# Everything above the last line only defines functions, so editing this file
# while it runs does not change what runs. The other scripts and libraries are
# copied to a temporary directory first and read from there.
set -u

# load <scripts dir>: copies the scripts, their libraries and plan-completion's
# markdown.jq to a temporary directory and sources the copied libraries.
load() {
  local src=$1
  run_dir=$(mktemp -d) || return 1
  scripts=$run_dir/git-spice-workflow/scripts
  lib_dir=$scripts/lib
  plan_lib_dir=$run_dir/plan-completion/scripts/lib
  mkdir -p "$scripts" "$plan_lib_dir" || return 1
  cp -R "$src/lib" "$src/pre-merge-check.sh" "$src/restack-stack.sh" "$scripts/" || return 1
  cp "$src/../../plan-completion/scripts/lib/markdown.jq" "$plan_lib_dir/" || return 1
  . "$lib_dir/result.sh" && . "$lib_dir/stack.sh" && . "$lib_dir/github.sh"
}

# finish <result> <reason> [merged JSON array] [waiting_on]
finish() {
  local code
  code=$(result_exit_code "$1")
  emit_result "$1" "$code" "$pr" "${3:-[]}" "${4:-null}" "$2"
  exit "$code"
}

on_exit() {
  [ -n "${restore_to:-}" ] && restore_head
  [ -n "${run_dir:-}" ] && rm -rf "$run_dir"
}

on_signal() {
  local back=${restore_to:-}
  if [ -n "$back" ]; then
    restore_to=""
    git switch --quiet --detach "$back" >/dev/null 2>&1
    [ "$(git rev-parse HEAD 2>/dev/null)" = "$back" ] && [ -z "$(git status --porcelain 2>/dev/null)" ] \
      || finish precondition_failed "中断され、作業場所の HEAD を $back に戻せなかった。HEAD を origin/main に切り離して置き直す"
  fi
  finish transient "中断された。走らせ直す"
}

# restore_head: checks out $restore_to detached; succeeds when HEAD is there
# and the tree is clean.
restore_head() {
  git switch --quiet --detach "$restore_to" >/dev/null 2>&1
  [ "$(git rev-parse HEAD 2>/dev/null)" = "$restore_to" ] && [ -z "$(git status --porcelain 2>/dev/null)" ]
}

parse_args() {
  [ $# -eq 2 ] && [ "$1" = --pr ] && [[ "$2" =~ ^[1-9][0-9]*$ ]] \
    || finish precondition_failed "使い方: merge-stack.sh --pr <PR 番号>"
  pr=$2
}

# check_workspace: the worktree has HEAD detached at a main commit and a clean
# tree (REQ-001). Runs before anything reads GitHub.
check_workspace() {
  local dirty rc
  git fetch --quiet origin || finish transient "git fetch origin が失敗した"
  git symbolic-ref -q HEAD >/dev/null \
    && finish precondition_failed "作業場所がブランチを取り出している。作業場所の HEAD を origin/main に切り離して置き直す"
  git merge-base --is-ancestor HEAD refs/remotes/origin/main
  rc=$?
  case $rc in
    0) ;;
    1) finish precondition_failed "作業場所の HEAD が origin/main の祖先でない。作業場所の HEAD を origin/main に切り離して置き直す" ;;
    *) finish transient "HEAD と origin/main の祖先の関係を確かめられなかった" ;;
  esac
  dirty=$(git status --porcelain) || finish transient "git status が失敗した"
  [ -z "$dirty" ] || finish precondition_failed "作業ツリーがきれいでない: $(one_line "$dirty")"
}

# read_stack: sets prs to the pull requests of the stack, bottom to top.
read_stack() {
  local numbers n one
  numbers=$(gh_stack_numbers "$repo" "$pr") || finish transient "PR #$pr のスタックを読めなかった"
  [ -n "$numbers" ] || finish transient "PR #$pr のスタックに PR の番号が無かった"
  prs='[]'
  for n in $numbers; do
    one=$(gh_pr "$n") || finish transient "PR #$n を読めなかった"
    prs=$(jq -c --argjson p "$one" '. + [$p]' <<<"$prs") || finish transient "PR #$n の内容を読めなかった"
  done
  all_prs=$prs
}

# choose_range: sets range_json to the bottom pull requests that are open,
# not drafts, approved and passing every check (REQ-002).
choose_range() {
  local chosen waiting why len
  chosen=$(jq -c '
    def passed: all((.statusCheckRollup // [])[];
      if .__typename == "StatusContext" then .state == "SUCCESS"
      else .status == "COMPLETED" and ((.conclusion // "") | IN("SUCCESS", "NEUTRAL", "SKIPPED"))
      end);
    def ready: .state == "OPEN" and .isDraft == false and .reviewDecision == "APPROVED" and passed;
    reduce .[] as $p ({stop: false, range: [], waiting: null, why: ""};
      if .stop then .
      elif ($p | ready) then .range += [$p]
      else .stop = true | .waiting = $p.number
        | .why = "state=\($p.state) draft=\($p.isDraft) review=\($p.reviewDecision) checks_passed=\($p | passed)"
      end)' <<<"$prs") || finish transient "PR の承認・チェックの状態を読めなかった"
  range_json=$(jq -c .range <<<"$chosen") || finish transient "マージする範囲を読めなかった"
  len=$(jq length <<<"$range_json") || finish transient "マージする範囲の長さを読めなかった"
  if [ "$len" -eq 0 ]; then
    waiting=$(jq -r .waiting <<<"$chosen")
    why=$(jq -r .why <<<"$chosen")
    finish wait "PR #$waiting の承認・チェックを待つ（$why）" '[]' "$waiting"
  fi
}

# check_order: each pull request of the range is based on the one below it,
# the bottom on main (REQ-003 (a)).
check_order() {
  local bad
  bad=$(jq -r '. as $r | range(0; length) as $i
    | (if $i == 0 then "main" else $r[$i - 1].headRefName end) as $want
    | select($r[$i].baseRefName != $want)
    | "PR #\($r[$i].number) の base が \($r[$i].baseRefName)（\($want) であるべき）"' <<<"$range_json") \
    || finish transient "スタックの並びを読めなかった"
  [ -z "$bad" ] || finish precondition_failed "スタックの並びが合わない: $(one_line "$bad")"
}

# check_worktrees: no worktree has a branch of the stack, or a branch stacked
# above its top, checked out (REQ-003 (b)).
check_worktrees() {
  local spice top held
  local -a names
  spice=$(spice_branches) || finish transient "git-spice ls が失敗した"
  top=$(jq -r '.[-1].headRefName' <<<"$all_prs")
  mapfile -t names < <(jq -r '.[].headRefName' <<<"$all_prs"; spice_above "$spice" "$top")
  held=$(checked_out_among "${names[@]}") || finish transient "git worktree list が失敗した"
  [ -z "$held" ] \
    || finish precondition_failed "スタックのブランチか上のブランチが worktree で取り出されている: $(one_line "$held")。その worktree を detached HEAD かスタック外のブランチに切り替えてから走らせ直す"
}

# is_stale: true when the bottom is BEHIND or a head does not contain the head
# below it (origin/main for the bottom) (REQ-004).
is_stale() {
  local lower sha rc
  [ "$(jq -r '.[0].mergeStateStatus' <<<"$range_json")" = BEHIND ] && return 0
  lower=$(git rev-parse --verify -q refs/remotes/origin/main) || finish transient "origin/main を読めなかった"
  for sha in $(jq -r '.[].headRefOid' <<<"$range_json"); do
    git merge-base --is-ancestor "$lower" "$sha" 2>/dev/null
    rc=$?
    case $rc in
      0) ;;
      1) return 0 ;;
      *) finish transient "コミット $sha と $lower の祖先の関係を確かめられなかった" ;;
    esac
    lower=$sha
  done
  return 1
}

# run_restack: restacks and pushes the stack, then ends this run.
run_restack() {
  local out rc reason
  out=$(bash "$scripts/restack-stack.sh" --branch "$(jq -r '.[-1].headRefName' <<<"$range_json")")
  rc=$?
  reason=$(jq -r '.reason // empty' <<<"$out" 2>/dev/null)
  case $rc in
    0) finish restacked "スタックを最新の main に積み直して push した。CI を待ってから走らせ直す" ;;
    20) finish restack_conflict "$reason" ;;
    21) finish push_check_failed "$reason" ;;
    23) finish precondition_failed "$reason" ;;
    *) finish transient "${reason:-restack-stack.sh が終了コード $rc で終わった}" ;;
  esac
}

main() {
  local src
  pr=null
  run_dir=""
  restore_to=""
  trap on_exit EXIT
  trap on_signal INT TERM
  src=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd) || exit 3
  if ! load "$src"; then
    printf '%s\n' '{"result":"transient","exit":3,"pr":null,"merged":[],"waiting_on":null,"reason":"スクリプトを一時ディレクトリへ写せなかった"}'
    exit 3
  fi
  parse_args "$@"
  check_workspace
  repo=$(gh_repo) || finish transient "gh repo view でリポジトリ名を読めなかった"
  read_stack
  choose_range
  check_order
  check_worktrees
  if is_stale; then run_restack; fi
  finish transient "マージの段はまだ作っていない"
}

main "$@"; exit $?
