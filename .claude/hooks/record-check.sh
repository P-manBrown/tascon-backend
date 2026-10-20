#!/usr/bin/env bash
set -uo pipefail

input=$(cat)

cwd=$(echo "$input" | jq -r '.cwd // empty')
if [ -z "$cwd" ]; then
  exit 0
fi

git_common_dir=$(git -C "$cwd" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || exit 0
main=$(dirname "$git_common_dir")
state_dir="$main/.claude/record-check-state"

hook_event_name=$(echo "$input" | jq -r '.hook_event_name // empty')
agent_id=$(echo "$input" | jq -r '.agent_id // empty')
if [ "$hook_event_name" = "PreToolUse" ]; then
  tool_name=$(echo "$input" | jq -r '.tool_name // empty')
  if [ "$tool_name" != "SubagentHandback" ] || [ -z "$agent_id" ]; then
    exit 0
  fi
  if [ -f "$state_dir/$agent_id" ]; then
    exit 0
  fi
elif [ "$hook_event_name" = "SubagentStop" ] || [ "$hook_event_name" = "Stop" ]; then
  stop_hook_active=$(echo "$input" | jq -r '.stop_hook_active // false')
  if [ "$stop_hook_active" = "true" ]; then
    exit 0
  fi
else
  exit 0
fi

agent_type=$(echo "$input" | jq -r '.agent_type // empty')
if [ "$hook_event_name" = "SubagentStop" ]; then
  if [ -z "$agent_type" ]; then
    exit 0
  fi
  if [ -f "$state_dir/$agent_id" ]; then
    rm "$state_dir/$agent_id"
    exit 0
  fi
fi

reason='作業を終える前に、このターン（サブエージェントは今回の作業）で次の記録が必要な事柄が生じていないか、各ルール・skillの定めに沿って確認し、未記録のものはすべて今記録する。
- planのDecision Log・Progress（plans-maintenanceルール）
- 技術的負債の新規記録・更新（tech-debt-tracker skill）
- Todoistへの進捗コメント（todoist-task-runner skill）
- ユーザーの指摘・決定（claude-md-maintenanceルールの置き場所判断に従い、プロジェクト全体のルールはCLAUDE.md・rules・skillsへ、個人の作業スタイル・ツール利用方針はmemoryへ）
該当がなければ何もせず終了する。'

if [ "$hook_event_name" = "PreToolUse" ]; then
  mkdir -p "$state_dir"
  touch "$state_dir/$agent_id"
  reason="$reason
記録が済んだら、もう一度SubagentHandbackで報告する。"
  jq -n --arg reason "$reason" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}'
else
  jq -n --arg reason "$reason" '{decision: "block", reason: $reason}'
fi
exit 0
