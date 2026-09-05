#!/usr/bin/env bash
set -uo pipefail

status=0

valid_status="Open|Accepted|Resolved"
valid_priority="High|Medium|Low"
valid_category="Architecture|Code|Test|Performance|Security|Infrastructure|Dependency|Documentation"

while IFS= read -r -d '' file; do
  td_status=$(grep -oP '(?<=\*\*Status:\*\* )\S+' "$file" || true)
  td_priority=$(grep -oP '(?<=\*\*Priority:\*\* )\S+' "$file" || true)
  td_category=$(grep -oP '(?<=\*\*Category:\*\* )\S+' "$file" || true)

  if [ -n "$td_status" ] && ! [[ "$td_status" =~ ^($valid_status)$ ]]; then
    echo "ERROR: $file has invalid Status: $td_status"
    status=1
  fi
  if [ -n "$td_priority" ] && ! [[ "$td_priority" =~ ^($valid_priority)$ ]]; then
    echo "ERROR: $file has invalid Priority: $td_priority"
    status=1
  fi
  if [ -n "$td_category" ] && ! [[ "$td_category" =~ ^($valid_category)$ ]]; then
    echo "ERROR: $file has invalid Category: $td_category"
    status=1
  fi
done < <(find .claude/tech-debt -name 'TD-*.md' -print0 2>/dev/null)

while IFS= read -r -d '' file; do
  dir=$(dirname "$file")
  while IFS= read -r link; do
    [[ "$link" =~ ^https?:// ]] && continue
    [[ "$link" =~ ^# ]] && continue
    path="${link%%#*}"
    [ -z "$path" ] && continue
    if [ ! -f "$dir/$path" ]; then
      echo "ERROR: $file has broken link: $link"
      status=1
    fi
  done < <(grep -oE '\]\([^)]+\)' "$file" | sed -E 's/^\]\(//; s/\)$//')
done < <(find ARCHITECTURE.md docs/decisions .claude/plans .claude/tech-debt -name '*.md' -print0 2>/dev/null)

exit $status
