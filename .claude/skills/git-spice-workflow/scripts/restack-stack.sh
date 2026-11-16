#!/usr/bin/env bash
# Usage: restack-stack.sh --branch <branch>
# Restacks the whole stack of the branch on the latest main and pushes the
# branches of the stack that have pull requests. Run it in a worktree whose
# tree is clean; no worktree, this one included, may have a stack branch
# checked out. The worktree's HEAD is put back as it was.
# Output (stdout): one JSON line
#   {"result", "exit", "pr": null, "merged": [], "waiting_on": null, "reason"}
# Exit: 0 restacked / 20 restack conflict (undone) / 21 push check failed /
#       23 precondition failed / 3 transient failure
set -u

finish() {
  local code
  if [ "$1" = restacked ]; then code=0; else code=$(result_exit_code "$1"); fi
  emit_result "$1" "$code" null '[]' null "$2"
  exit "$code"
}

# return_head: checks out what the worktree had before (the branch, or the
# commit detached); succeeds when the tree is clean afterwards.
return_head() {
  if [ -n "$orig_branch" ]; then
    git switch --quiet "$orig_branch" >/dev/null 2>&1 || return 1
  else
    git switch --quiet --detach "$orig_commit" >/dev/null 2>&1 || return 1
  fi
  [ -z "$(git status --porcelain 2>/dev/null)" ]
}

# undo_restack: puts the stack branches, refs/spice/data and HEAD back to the
# snapshot taken before the restack.
undo_restack() {
  local ref now
  git switch --quiet --detach "$orig_commit" >/dev/null 2>&1 || return 1
  for ref in "${!snapshot[@]}"; do
    now=$(git rev-parse --verify -q "$ref") || now=""
    [ "$now" = "${snapshot[$ref]}" ] && continue
    git update-ref "$ref" "${snapshot[$ref]}" || return 1
  done
  return_head
}

main() {
  local dir branch spice stack_json not_synced held top b lower rc rebase_dir conflicted
  local -a stack with_pr
  dir=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd) || exit 3
  . "$dir/lib/result.sh" || exit 3
  . "$dir/lib/stack.sh" || exit 3

  [ $# -eq 2 ] && [ "$1" = --branch ] && [ -n "$2" ] \
    || finish precondition_failed "使い方: restack-stack.sh --branch <スタックのブランチ>"
  branch=$2

  held=$(git status --porcelain) || finish transient "git status が失敗した"
  [ -z "$held" ] || finish precondition_failed "作業ツリーがきれいでない: $(one_line "$held")"

  spice=$(spice_branches) || finish transient "git-spice ls が失敗した"
  stack_json=$(spice_stack "$spice" "$branch")
  [ -z "$(jq -r '.error // empty' <<<"$stack_json")" ] \
    || finish precondition_failed "$(jq -r .error <<<"$stack_json")"
  mapfile -t stack < <(jq -r '.stack[]' <<<"$stack_json")
  top=${stack[-1]}
  mapfile -t with_pr < <(jq -r --argjson s "$(jq -c .stack <<<"$stack_json")" \
    '$s[] as $n | .[] | select(.name == $n and .change != null) | .name' <<<"$spice")

  not_synced=$(jq -r --argjson s "$(jq -c .stack <<<"$stack_json")" \
    '$s[] as $n | .[] | select(.name == $n and .change != null)
     | select((.push.ahead // -1) != 0 or (.push.behind // -1) != 0) | .name' <<<"$spice")
  [ -z "$not_synced" ] \
    || finish precondition_failed "ローカルとリモートが一致していない: $(one_line "$not_synced")。push か pull で合わせてから走らせ直す"

  held=$(checked_out_among "${stack[@]}") || finish transient "git worktree list が失敗した"
  [ -z "$held" ] \
    || finish precondition_failed "スタックのブランチが worktree で取り出されている: $(one_line "$held")。その worktree を detached HEAD かスタック外のブランチに切り替えてから走らせ直す"

  orig_branch=$(git symbolic-ref -q --short HEAD) || orig_branch=""
  orig_commit=$(git rev-parse HEAD) || finish transient "HEAD を読めなかった"

  git-spice repo sync --restack=none >&2 || finish transient "git-spice repo sync が失敗した"

  declare -gA snapshot=()
  for b in "${stack[@]}"; do
    snapshot["refs/heads/$b"]=$(git rev-parse --verify -q "refs/heads/$b") \
      || finish precondition_failed "ローカルにブランチ $b が無い"
  done
  snapshot[refs/spice/data]=$(git rev-parse --verify -q refs/spice/data) || unset 'snapshot[refs/spice/data]'

  git-spice stack restack --branch "$top" >&2
  rc=$?
  if [ "$rc" -ne 0 ]; then
    rebase_dir=$(git rev-parse --git-path rebase-merge)
    conflicted=""
    [ -f "$rebase_dir/head-name" ] && conflicted=$(<"$rebase_dir/head-name")
    conflicted=${conflicted#refs/heads/}
    git-spice rebase abort >&2
    undo_restack || finish precondition_failed "積み直しを取り消せなかった。HEAD を $orig_commit に、スタックのブランチを積み直す前の参照に戻す"
    [ -n "$conflicted" ] \
      && finish restack_conflict "$conflicted の積み直しで衝突した（積み直しは取り消した）。スタックを手元で積み直して衝突を解き、push してから走らせ直す"
    finish transient "git-spice stack restack が終了コード $rc で失敗した（積み直しは取り消した）"
  fi
  return_head || finish precondition_failed "積み直しの後、作業場所を元の HEAD（${orig_branch:-$orig_commit}）に戻せなかった"

  lower=main
  for b in "${stack[@]}"; do
    git merge-base --is-ancestor "refs/heads/$lower" "refs/heads/$b"
    rc=$?
    case $rc in
      0) ;;
      1) finish push_check_failed "積み直した $b が $lower を祖先に持たない。push していない" ;;
      *) finish transient "$b と $lower の祖先の関係を確かめられなかった" ;;
    esac
    lower=$b
  done

  for b in "${with_pr[@]}"; do
    git-spice branch submit --update-only --no-web --branch "$b" >&2 \
      || finish transient "$b の push（git-spice branch submit）が失敗した"
  done
  finish restacked "スタック（${stack[*]}）を main に積み直して push した"
}

main "$@"
exit $?
