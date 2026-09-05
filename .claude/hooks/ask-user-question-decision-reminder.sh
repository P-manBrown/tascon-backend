#!/bin/bash
set -uo pipefail

cat >/dev/null

jq -n '{
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: "AskUserQuestionへの回答を受け取りました。この決定は関連するexecution-planのDecision Logへの反映が必要か確認してください。"
  }
}'
