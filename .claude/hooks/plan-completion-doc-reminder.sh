#!/bin/bash
# PreToolUse(Bash)フックから呼ばれる。
# .claude/plans/active/ から .claude/plans/completed/ へのファイル移動
# (git mv / mv どちらも)を検知したら、横断的な設計判断の抽出・
# ARCHITECTURE.mdへの影響確認を促すリマインダーをブロックせずに注入する。
set -euo pipefail

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty' 2>/dev/null || echo "")
command_flat=$(printf '%s' "$command" | tr '\n' ' ')

if echo "$command_flat" | grep -qE '(git mv|mv) .*plans/active/.*plans/completed/'; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "allow",
      additionalContext: "plan完了処理を検知しました。completed化する前に、このplanに保存が必要な設計判断が含まれていないか(あればdocs/design-docs/へ抽出)、ARCHITECTURE.mdを更新する必要がないか確認してください。"
    }
  }'
else
  exit 0
fi
