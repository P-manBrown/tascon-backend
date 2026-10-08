#!/bin/bash
set -euo pipefail

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // empty')

detected=0
case "$tool_name" in
  Bash)
    command=$(echo "$input" | jq -r '.tool_input.command // empty' 2>/dev/null || echo "")
    command_flat=$(printf '%s' "$command" | tr '\n' ' ')
    if echo "$command_flat" | grep -q 'plans/active/' && echo "$command_flat" | grep -q 'plans/completed/'; then
      detected=1
    fi
    ;;
  Write)
    file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null || echo "")
    if echo "$file_path" | grep -qE '\.claude/plans/completed/.*\.md$'; then
      detected=1
    fi
    ;;
esac

if [ "$detected" = "1" ]; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "allow",
      additionalContext: "Planをcompleted化する前に、`execution-plan` SKILL.mdの「完了処理」セクションに記載の手順(claude-mem監査・design-docs抽出・ARCHITECTURE.md更新・memory/rules/skills昇格等)を実施済みか確認してください。"
    }
  }'
else
  exit 0
fi
