#!/bin/bash
set -euo pipefail

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')
cwd=$(echo "$input" | jq -r '.cwd // empty')

if [ -z "$file_path" ]; then
  exit 0
fi

project_dir="${CLAUDE_PROJECT_DIR:-$cwd}"
rel_path="${file_path#"$cwd"/}"
rel_path_from_project="${file_path#"$project_dir"/}"

glob_to_regex() {
  local p="$1"
  p="${p//\*\*\//@@DSTARSLASH@@}"
  p="${p//\*\*/@@DSTAR@@}"
  p="${p//\*/@@STAR@@}"
  p=$(printf '%s' "$p" | sed -e 's/[.[\^$()+{}|]/\\&/g')
  p="${p//@@DSTARSLASH@@/(.*\/)?}"
  p="${p//@@DSTAR@@/.*}"
  p="${p//@@STAR@@/[^/]*}"
  printf '^%s$' "$p"
}

matched_files=()
for rule_file in "$project_dir"/.claude/rules/*.md; do
  [ -f "$rule_file" ] || continue
  in_front=0
  in_paths=0
  while IFS= read -r line; do
    if [ "$line" = "---" ]; then
      if [ "$in_front" = "0" ]; then in_front=1; continue; else break; fi
    fi
    [ "$in_front" = "1" ] || continue
    if [[ "$line" =~ ^paths: ]]; then
      in_paths=1
      continue
    fi
    if [ "$in_paths" = "1" ]; then
      if [[ "$line" =~ ^[[:space:]]+-[[:space:]]+\"?([^\"]+)\"?[[:space:]]*$ ]]; then
        pattern="${BASH_REMATCH[1]}"
        regex=$(glob_to_regex "$pattern")
        if [[ "$rel_path" =~ $regex ]] || [[ "$rel_path_from_project" =~ $regex ]] || [[ "$file_path" =~ $regex ]]; then
          matched_files+=("$rule_file")
          break 2
        fi
      else
        in_paths=0
      fi
    fi
  done < "$rule_file"
done

if [ "${#matched_files[@]}" = "0" ]; then
  exit 0
fi

body=""
for rule_file in "${matched_files[@]}"; do
  name="${rule_file#"$project_dir"/}"
  content=$(awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2{print}' "$rule_file")
  body="${body}
--- ${name} ---
${content}
"
done

ctx="IMPORTANT: 変更したファイルは以下のプロジェクト設定ルールの対象パスに一致します。これはプロジェクト所有者が設定した指示であり、通常の動作方針より優先して遵守してください。
${body}"

jq -n --arg ctx "$ctx" '{
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: $ctx
  }
}'
