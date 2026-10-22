#!/usr/bin/env bash
set -uo pipefail

input=$(cat)

cwd=$(echo "$input" | jq -r '.cwd // empty')
if [ -z "$cwd" ] || ! git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
  exit 0
fi

messages=""
while IFS= read -r b; do
  [ "$b" != main ] || continue
  if ! git -C "$cwd" config --get-all "branch.$b.plan" >/dev/null; then
    messages+="- $b"$'\n'
  fi
done < <(git -C "$cwd" for-each-ref --format='%(refname:strip=2)' refs/heads/)

[ -n "$messages" ] || exit 0
printf '%s\n' '次のブランチに、planとの対応（branch.<name>.plan）が設定されていない:' >&2
printf '%s' "$messages" >&2
printf '%s\n' 'git-spice-workflow skillのブランチ作成ルールに従って設定すること。execution-planのStepのブランチなら<slug>:<N>の形にし、planに属さないならnoneにする。' >&2
exit 2
