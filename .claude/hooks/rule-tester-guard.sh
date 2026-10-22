#!/usr/bin/env bash
set -uo pipefail

input=$(cat)

cwd=$(echo "$input" | jq -r '.cwd // empty')
root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || exit 0

tool_name=$(echo "$input" | jq -r '.tool_name // empty')
case "$tool_name" in
  Read)
    path=$(echo "$input" | jq -r '.tool_input.file_path // empty')
    [ -n "$path" ] || exit 0
    ;;
  Grep|Glob)
    path=$(echo "$input" | jq -r '.tool_input.path // empty')
    path=${path:-$cwd}
    ;;
  *) exit 0 ;;
esac

if [[ "$path" != /* ]]; then
  path="$cwd/$path"
fi
path=$(realpath -m -- "$path") || exit 0
root=$(realpath -m -- "$root") || exit 0

for directory in rules skills plans memory; do
  forbidden="$root/.claude/$directory"
  if [[ "$path" = "$forbidden" || "$path" = "$forbidden/"* ]] ||
    { [[ "$tool_name" = Grep || "$tool_name" = Glob ]] &&
      [[ "$path" = / || "$forbidden" = "$path/"* ]]; }; then
    reason='比較テストの条件を保つため、.claude/rules・skills・plans・memoryの中身と、それらを含む範囲の検索は使えない。ルールは関係するファイルを読んだときの差し込み、skillはSkillツールで使う。'
    jq -n --arg reason "$reason" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}'
    exit 0
  fi
done
exit 0
