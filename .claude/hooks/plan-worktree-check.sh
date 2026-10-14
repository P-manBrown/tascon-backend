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

for f in "$plans_dir"/*.md; do
  [ -e "$f" ] || continue
  if grep -qxF "Worktree: ${cwd}" "$f"; then
    exit 0
  fi
done

echo "${plans_dir}のどのplanにも'Worktree: ${cwd}'行がありません。plans-maintenanceルールに従い、作業中のplanに'Worktree: ${cwd}'を追記してください。" >&2
exit 2
