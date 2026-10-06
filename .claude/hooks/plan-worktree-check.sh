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

missing=()
for f in "$plans_dir"/*.md; do
  [ -e "$f" ] || continue
  if ! grep -qF "Worktree: ${cwd}" "$f"; then
    missing+=("$f")
  fi
done

if [ "${#missing[@]}" -gt 0 ]; then
  echo "以下のplanファイルに現在のworktree絶対パスと一致する'Worktree: ${cwd}'行がありません。plans-maintenanceルールに従い記載してください:" >&2
  printf '%s\n' "${missing[@]}" >&2
  exit 2
fi

exit 0
