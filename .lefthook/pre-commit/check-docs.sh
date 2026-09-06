#!/usr/bin/env bash
set -uo pipefail

status=0

fail() {
  echo "ERROR: $1"
  status=1
}

require_fields() {
  local file="$1"
  shift
  for field in "$@"; do
    grep -q -- "\*\*${field}:\*\*" "$file" || fail "$file is missing required field: $field"
  done
}

require_headings() {
  local file="$1"
  shift
  for heading in "$@"; do
    grep -q "^## ${heading}\$" "$file" || fail "$file is missing required heading: $heading"
  done
}

# --- tech-debt: 固定値検証 ---
valid_td_status="Open|Accepted|Resolved"
valid_td_priority="High|Medium|Low"
valid_td_category="Architecture|Code|Test|Performance|Security|Infrastructure|Dependency|Documentation"

while IFS= read -r -d '' file; do
  td_status=$(grep -oP '(?<=\*\*Status:\*\* )\S+' "$file" || true)
  td_priority=$(grep -oP '(?<=\*\*Priority:\*\* )\S+' "$file" || true)
  td_category=$(grep -oP '(?<=\*\*Category:\*\* )\S+' "$file" || true)

  [ -n "$td_status" ] && ! [[ "$td_status" =~ ^($valid_td_status)$ ]] && fail "$file has invalid Status: $td_status"
  [ -n "$td_priority" ] && ! [[ "$td_priority" =~ ^($valid_td_priority)$ ]] && fail "$file has invalid Priority: $td_priority"
  [ -n "$td_category" ] && ! [[ "$td_category" =~ ^($valid_td_category)$ ]] && fail "$file has invalid Category: $td_category"

  require_fields "$file" "Status" "Priority" "Category" "Area" "Detected" "Todoist Task ID" "Description" "Impact" "Proposed Resolution" "Related"

  placeholders=$(grep -nE '^(# TD-[0-9]+ — <[^>]+>|- \*\*[A-Za-z ]+:\*\* <[^>]+>)$' "$file" || true)
  [ -n "$placeholders" ] && fail "$file has unfilled placeholder(s) at line(s): $(echo "$placeholders" | cut -d: -f1 | tr '\n' ' ')"
done < <(find .claude/tech-debt -name 'TD-*.md' -print0 2>/dev/null)

# --- decisions: 固定値検証・必須フィールド/見出し・孤立ファイル検知 ---
valid_decision_status="Proposed|Accepted|Deprecated|Superseded by .+"
valid_verification_status="Verified|Unverified|Stale"

while IFS= read -r -d '' file; do
  base=$(basename "$file")
  [ "$base" = "index.md" ] && continue

  d_status=$(grep -oP '(?<=\*\*Status:\*\* ).+' "$file" || true)
  d_vstatus=$(grep -oP '(?<=\*\*Verification Status:\*\* )\S+' "$file" || true)

  [ -n "$d_status" ] && ! [[ "$d_status" =~ ^($valid_decision_status)$ ]] && fail "$file has invalid Status: $d_status"
  [ -n "$d_vstatus" ] && ! [[ "$d_vstatus" =~ ^($valid_verification_status)$ ]] && fail "$file has invalid Verification Status: $d_vstatus"

  require_fields "$file" "Status" "Verification Status" "Date"
  require_headings "$file" "Context" "Decision" "Consequences"

  if [ -f docs/decisions/index.md ] && ! grep -q "($base)" docs/decisions/index.md; then
    fail "docs/decisions/$base is not linked from index.md"
  fi
done < <(find docs/decisions -maxdepth 1 -name '*.md' -print0 2>/dev/null)

# --- 全体: Markdown相対リンク切れチェック ---
while IFS= read -r -d '' file; do
  dir=$(dirname "$file")
  while IFS= read -r link; do
    [[ "$link" =~ ^https?:// ]] && continue
    [[ "$link" =~ ^# ]] && continue
    path="${link%%#*}"
    [ -z "$path" ] && continue
    if [ ! -f "$dir/$path" ]; then
      fail "$file has broken link: $link"
    fi
  done < <(grep -oE '\]\([^)]+\)' "$file" | sed -E 's/^\]\(//; s/\)$//')
done < <(find ARCHITECTURE.md docs .claude/plans .claude/tech-debt -name '*.md' -print0 2>/dev/null)

exit $status
