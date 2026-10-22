#!/usr/bin/env bash
set -uo pipefail

status=0

while read -r local_ref local_sha remote_ref remote_sha; do
  [[ "$local_ref" == refs/heads/* ]] || continue
  [[ "$local_sha" =~ ^0+$ ]] && continue
  branch="${local_ref#refs/heads/}"
  while IFS= read -r value; do
    [[ "$value" =~ ^(.+):([0-9]+)$ ]] || continue
    plan="${BASH_REMATCH[1]}"
    step="${BASH_REMATCH[2]}"
    file=".claude/plans/active/$plan.md"
    if ! content=$(git show "$local_sha:$file" 2>/dev/null); then
      echo "ERROR: $branch is set to plan $plan Step$step, but $file does not exist in the pushed commit"
      status=1
      continue
    fi
    progress=$(sed -n '/^## Progress$/,/^## /{ /^## Progress$/d; /^## /d; p; }' <<< "$content")
    if ! grep -q "^- \[x\] Step$step: " <<< "$progress"; then
      echo "ERROR: $file: $branch is set to Step$step, but Step$step is not checked in its Progress"
      status=1
    fi
  done < <(git config --get-all "branch.$branch.plan" || true)
done

exit "$status"
