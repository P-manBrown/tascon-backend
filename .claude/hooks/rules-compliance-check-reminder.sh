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

matched=()
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
          matched+=("${rule_file#"$project_dir"/}")
          break 2
        fi
      else
        in_paths=0
      fi
    fi
  done < "$rule_file"
done

if [ "${#matched[@]}" = "0" ]; then
  exit 0
fi

names=$(IFS='、'; echo "${matched[*]}")
ctx="変更したファイルは以下のルールの対象パスに一致します: ${names}。変更後に内容がこれらのルールに遵守できているか確認してください。"

jq -n --arg ctx "$ctx" '{
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: $ctx
  }
}'
