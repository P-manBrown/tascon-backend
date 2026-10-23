#!/usr/bin/env bash
set -uo pipefail

status=0

while read -r local_ref local_sha remote_ref remote_sha; do
  [[ "$local_ref" == refs/heads/* ]] || continue
  [[ "$local_sha" =~ ^0+$ ]] && continue
  branch="${local_ref#refs/heads/}"
  while IFS= read -r file; do
    [[ "$file" == .claude/plans/active/*.md ]] || continue
    [[ "${file#.claude/plans/active/}" == */* ]] && continue
    content=$(git show "$local_sha:$file")
    while IFS= read -r entry; do
      entry=$(sed 's/^- //; s/`//g; s/^[[:space:]]*//; s/[[:space:]]*$//' <<< "$entry")
      [[ "$entry" =~ ^(.*)（(Step[0-9]+)）$ ]] || continue
      entry_branch="${BASH_REMATCH[1]}"
      step="${BASH_REMATCH[2]}"
      entry_branch=$(sed 's/[[:space:]]*$//' <<< "$entry_branch")
      [ "$entry_branch" = "$branch" ] || continue
      progress=$(sed -n '/^## Progress$/,/^## /{ /^## Progress$/d; /^## /d; p; }' <<< "$content")
      if ! grep -q "^- \[x\] $step: " <<< "$progress"; then
        echo "ERROR: $file lists $branch as $step, but $step is not checked in its Progress"
        status=1
      fi
    done < <(sed -n '/^## Branches$/,/^## /{ /^## Branches$/d; /^## /d; /^- /p; }' <<< "$content")
  done < <(git ls-tree --name-only "$local_sha" .claude/plans/active/)
done

exit "$status"
