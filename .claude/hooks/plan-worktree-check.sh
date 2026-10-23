#!/usr/bin/env bash
set -uo pipefail

input=$(cat)

stop_hook_active=$(echo "$input" | jq -r '.stop_hook_active // false')
if [ "$stop_hook_active" = "true" ]; then
  exit 0
fi

cwd=$(echo "$input" | jq -r '.cwd // empty')
if [ -z "$cwd" ]; then
  exit 0
fi

case "$cwd" in
  */.claude/worktrees/*) ;;
  *) exit 0 ;;
esac

plans_dir="$cwd/.claude/plans/active"
if [ ! -d "$plans_dir" ]; then
  exit 0
fi

has_plans=false
for f in "$plans_dir"/*.md; do
  [ -e "$f" ] || continue
  has_plans=true
  if WORKTREE_CWD="$cwd" awk '
    /^## / { exit }
    {
      sub(/[[:space:]]+$/, "")
      if ($0 == "Worktree: " ENVIRON["WORKTREE_CWD"]) {
        found = 1
        exit
      }
    }
    END { exit !found }
  ' "$f"; then
    exit 0
  fi
done

if [ "$has_plans" = "false" ]; then
  exit 0
fi

echo "${plans_dir}のどのplanにも、最初の'## '見出しより前に'Worktree: ${cwd}'行がありません。このworktreeでplanの作業をしている場合は、plans-maintenanceルールに従い作業中のplanの冒頭に'Worktree: ${cwd}'を1行で追記してください。planの作業をしていない場合（レビュー・調査等）は対応不要です。無関係なplanには追記しないでください。" >&2
exit 2
