#!/bin/bash
# PostToolUse(AskUserQuestion)フックから呼ばれる。
# 質問への回答を受け取った直後に、その決定が関連する
# execution-planのDecision Logへ反映すべきでないか確認を促す。
# PostToolUseではpermissionDecisionは無視されるため付与しない。
set -uo pipefail

cat >/dev/null

jq -n '{
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: "AskUserQuestionへの回答を受け取りました。この決定は関連するexecution-planのDecision Logへの反映が必要か確認してください。"
  }
}'
