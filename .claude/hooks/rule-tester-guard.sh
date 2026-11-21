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
# Check the path as given (symlinks kept) and the real path (symlinks resolved):
# in a worktree .claude/memory is a symlink to a directory outside the root.
lex_path=$(realpath -m -s -- "$path") || exit 0
lex_root=$(realpath -m -s -- "$root") || exit 0
real_path=$(realpath -m -- "$path") || exit 0
real_root=$(realpath -m -- "$root") || exit 0

is_fixture() {
  [[ "$2" = "$1/docs/design/plans/rule-test-fixture.md" || "$2" = "$1/.claude/plans/rule-test-fixture.md" ]]
}

if [[ "$tool_name" = Read ]] &&
  is_fixture "$lex_root" "$lex_path" && is_fixture "$real_root" "$real_path"; then
  exit 0
fi

for form in lex real; do
  case "$form" in
    lex) path=$lex_path root=$lex_root ;;
    real) path=$real_path root=$real_root ;;
  esac
  for forbidden in "$root/.claude/rules" "$root/.claude/skills" "$root/docs/design/plans" "$root/.claude/plans" "$root/.claude/memory"; do
    if [[ "$path" = "$forbidden" || "$path" = "$forbidden/"* ]] ||
      { [[ "$tool_name" = Grep || "$tool_name" = Glob ]] &&
        [[ "$path" = / || "$forbidden" = "$path/"* ]]; }; then
      reason='比較テストの条件を保つため、.claude/rules・.claude/skills・docs/design/plans・.claude/plans・.claude/memoryの中身と、それらを含む範囲の検索は使えない。ルールは関係するファイルを読んだときの差し込み、skillはSkillツールで使う。'
      jq -n --arg reason "$reason" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}'
      exit 0
    fi
  done
done
exit 0
