#!/usr/bin/env bash
set -uo pipefail

input=$(cat)

cwd=$(echo "$input" | jq -r '.cwd // empty')
if [ -z "$cwd" ] || ! git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
  exit 0
fi

main_ref=main
if ! git -C "$cwd" rev-parse --verify -q "refs/heads/$main_ref" >/dev/null; then
  exit 0
fi

main_checkout="$(dirname "$(git -C "$cwd" rev-parse --path-format=absolute --git-common-dir)")"
state_dir="$main_checkout/.claude/hook-state/review-summary-cleanup"
mkdir -p "$state_dir"
main_file="$state_dir/main"
current_main=$(git -C "$cwd" rev-parse "refs/heads/$main_ref")

if [ ! -f "$main_file" ]; then
  printf '%s\n' "$current_main" >"$main_file"
  exit 0
fi

previous_main=$(cat "$main_file")
trap 'printf "%s\n" "$current_main" >"$main_file"' EXIT
[ "$previous_main" != "$current_main" ] || exit 0
git -C "$cwd" merge-base --is-ancestor "$previous_main" "$current_main" 2>/dev/null || exit 0

reviews_dir="$main_checkout/.claude/reviews"
[ -d "$reviews_dir" ] || exit 0

while IFS= read -r -d '' file; do
  rel=${file#"$reviews_dir"/}
  branch=${rel%.md}
  git -C "$cwd" rev-parse --verify -q "refs/heads/$branch" >/dev/null || rm -f -- "$file"
done < <(find "$reviews_dir" -type f -name '*.md' -print0)

find "$reviews_dir" -mindepth 1 -type d -empty -delete
exit 0
