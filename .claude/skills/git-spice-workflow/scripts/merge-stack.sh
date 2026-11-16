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

# check_plan_records: plan-completing pull requests of the range (a ✅ Plan
# line) record their current head in Testing, and no Plan line is unreadable
# (REQ-005).
check_plan_records() {
  local findings
  findings=$(jq -r -L "$plan_lib_dir" -L "$lib_dir" '
    include "markdown";
    include "pr-body";
    .[] | . as $p | ($p.body // "") as $b | ($b | unreadable_lines) as $bad
    | if ($bad | length) > 0 then $bad[] | "PR #\($p.number) の Plan 行が読めない: \(.)"
      elif ($b | plan_lines | any(.mark == "✅")) and (($b | has_head_record($p.headRefOid)) | not)
      then "PR #\($p.number) の Testing に head \($p.headRefOid[0:7]) で判定した記録が無い"
      else empty
      end' <<<"$range_json") || finish transient "PR 本文を読めなかった"
  [ -z "$findings" ] || finish precondition_failed "$(one_line "$findings")"
}

# run_pre_merge_check: runs pre-merge-check.sh once per commit at the head of
# the range's top, recording pass or fail under the common git directory,
# and puts HEAD back where it was (REQ-006).
run_pre_merge_check() {
  local sha dir record log rc changed back
  sha=$(jq -r '.[-1].headRefOid' <<<"$range_json")
  dir=$(git rev-parse --path-format=absolute --git-common-dir)/pre-merge-checks
  mkdir -p "$dir" || finish transient "$dir を作れなかった"
  record=$dir/$sha
  log=$dir/$sha.log
  if [ -f "$record" ]; then
    case $(<"$record") in
      pass) return 0 ;;
      fail) finish pre_merge_check_failed "マージ前の確かめが $sha で失敗している。出力: $log。環境の一時的な失敗なら、環境を直してから $record と $log を消して走らせ直す" ;;
      *) finish precondition_failed "マージ前の確かめの記録 $record の中身が pass でも fail でもない" ;;
    esac
  fi
  restore_to=$(git rev-parse HEAD) || finish transient "HEAD を読めなかった"
  if ! git switch --quiet --detach "$sha"; then
    back=$restore_to
    if ! restore_head; then
      changed=$(git status --porcelain)
      restore_to=""
      finish precondition_failed "作業場所の HEAD を $back に戻せなかった。変わったファイル: $(one_line "$changed")"
    fi
    restore_to=""
    finish transient "コミット $sha に移れなかった"
  fi
  (cd "$(git rev-parse --show-toplevel)" && bash "$scripts/pre-merge-check.sh") >"$log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then printf 'pass\n' >"$record"; else printf 'fail\n' >"$record"; fi
  back=$restore_to
  if ! restore_head; then
    changed=$(git status --porcelain)
    restore_to=""
    finish precondition_failed "マージ前の確かめの後、作業場所の HEAD を $back に戻せなかった。変わったファイル: $(one_line "$changed")"
  fi
  restore_to=""
  [ "$rc" -eq 0 ] \
    || finish pre_merge_check_failed "マージ前の確かめが $sha で失敗した（終了コード $rc）。出力: $log。環境の一時的な失敗なら、環境を直してから $record と $log を消して走らせ直す"
}

# request_merge: one asynchronous squash merge of the range's top (REQ-007).
request_merge() {
  local top sha uuid message
  top=$(jq -r '.[-1].number' <<<"$range_json")
  sha=$(jq -r '.[-1].headRefOid' <<<"$range_json")
  gh_merge_async "$repo" "$top" "$sha"
  case $http_code in
    200) return 0 ;;
    202 | 409)
      uuid=$(jq -r '.details.uuid // empty' <<<"$http_body" 2>/dev/null)
      [ -n "$uuid" ] || finish transient "merge-async の応答（HTTP $http_code）に UUID が無い"
      wait_for_merge "$top" "$uuid"
      ;;
    "" | 5??) finish transient "merge-async の要求が失敗した（HTTP ${http_code:-応答なし}）。走らせ直す" ;;
    *)
      message=$(jq -r '.message // .details.message // empty' <<<"$http_body" 2>/dev/null)
      finish merge_rejected "GitHub が PR #$top のマージを断った（HTTP $http_code）: $message"
      ;;
  esac
}

# wait_for_merge <number> <uuid>: polls the request until it is merged.
wait_for_merge() {
  local top=$1 uuid=$2 interval=${MERGE_STACK_POLL_INTERVAL:-10} timeout=${MERGE_STACK_POLL_TIMEOUT:-900}
  local deadline result status
  [[ "$interval" =~ ^[0-9]+$ ]] || interval=10
  [[ "$timeout" =~ ^[0-9]+$ ]] || timeout=900
  deadline=$((SECONDS + timeout))
  while :; do
    result=$(gh_merge_async_result "$repo" "$top" "$uuid") \
      || finish transient "merge-async の結果を問い合わせられなかった（UUID $uuid）。走らせ直す"
    status=$(jq -r .status <<<"$result")
    case $status in
      merged) return 0 ;;
      failed) finish merge_rejected "GitHub が PR #$top をマージできなかった: $(jq -r '.details.message // empty' <<<"$result")" ;;
      pending | enqueued) ;;
      *) finish transient "merge-async の結果の status が分からない: $status" ;;
    esac
    [ "$SECONDS" -lt "$deadline" ] \
      || finish transient "merge-async の結果が $timeout 秒のうちに出なかった（UUID $uuid）。走らせ直すと問い合わせ直す"
    sleep "$interval"
  done
}

# after_merge <merged pull requests JSON>: aligns the local repository with
# GitHub without restacking or pushing (REQ-008). The remaining pull requests
# are in prs.
after_merge() {
  local merged=$1 numbers b local_sha remote_sha left="" rc spice bottom
  numbers=$(jq -c 'map(.number)' <<<"$merged")
  git fetch --quiet --prune origin || finish transient "マージの後の git fetch --prune が失敗した" "$numbers"
  git-spice repo sync --restack=none >&2 || finish transient "マージの後の git-spice repo sync が失敗した" "$numbers"
  for b in $(jq -r '.[] | select(.state == "OPEN") | .headRefName' <<<"$prs"); do
    remote_sha=$(git rev-parse --verify -q "refs/remotes/origin/$b") || continue
    local_sha=$(git rev-parse --verify -q "refs/heads/$b") || continue
    [ "$local_sha" = "$remote_sha" ] && continue
    git update-ref "refs/heads/$b" "$remote_sha" "$local_sha" \
      || finish transient "$b を origin/$b に合わせられなかった" "$numbers"
  done
  for b in $(jq -r '.[].headRefName' <<<"$merged"); do
    git show-ref --verify -q "refs/heads/$b" && left+="${left:+, }$b（ローカル）"
    git ls-remote --exit-code --heads origin "refs/heads/$b" >/dev/null 2>&1
    rc=$?
    case $rc in
      0) left+="${left:+, }$b（リモート）" ;;
      2) ;;
      *) finish transient "git ls-remote が失敗した" "$numbers" ;;
    esac
  done
  [ -z "$left" ] || finish precondition_failed "マージしたブランチが残っている: $left" "$numbers"
  bottom=$(jq -r '[.[] | select(.state == "OPEN")][0].headRefName // empty' <<<"$prs")
  if [ -n "$bottom" ] && git show-ref --verify -q "refs/heads/$bottom"; then
    spice=$(spice_branches) || finish transient "git-spice ls が失敗した" "$numbers"
    [ "$(jq -r --arg b "$bottom" '.[] | select(.name == $b) | .down.name // empty' <<<"$spice")" = main ] \
      || finish precondition_failed "git-spice の記録で $bottom の土台が main になっていない" "$numbers"
  fi
}

# settle_merged_bottom: when the stack starts with merged pull requests (an
# earlier run stopped after merging), aligns the local repository for them and
# ends this run (REQ-009).
settle_merged_bottom() {
  local merged
  merged=$(jq -c 'reduce .[] as $p ({open: false, out: []};
      if .open then . elif $p.state == "MERGED" then .out += [$p] else .open = true end) | .out' <<<"$prs")
  [ "$(jq length <<<"$merged")" -eq 0 ] && return 0
  prs=$(jq -c --argjson m "$merged" '.[($m | length):]' <<<"$prs")
  check_worktrees
  after_merge "$merged"
  finish merged "マージ済みの PR の後片付けをした。続きがあれば走らせ直す" "$(jq -c 'map(.number)' <<<"$merged")"
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
  settle_merged_bottom
  choose_range
  check_order
  check_worktrees
  if is_stale; then run_restack; fi
  check_plan_records
  run_pre_merge_check
  check_worktrees
  request_merge
  local merged_numbers
  merged_numbers=$(jq -c 'map(.number)' <<<"$range_json")
  prs=$(jq -c --argjson m "$range_json" '.[($m | length):]' <<<"$prs")
  after_merge "$range_json"
  finish merged "PR $(jq -r 'map("#\(.)") | join(", ")' <<<"$merged_numbers") をマージした" "$merged_numbers"
}

main "$@"; exit $?
