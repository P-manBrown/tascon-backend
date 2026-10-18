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

state_dir="$(dirname "$(git -C "$cwd" rev-parse --path-format=absolute --git-common-dir)")/.claude/plan-completion-state"
mkdir -p "$state_dir"
branches_file="$state_dir/branches"
main_file="$state_dir/main"

current_branches=$(git -C "$cwd" for-each-ref --format='%(refname:short)' refs/heads | sort)
current_main=$(git -C "$cwd" rev-parse "refs/heads/$main_ref")

if [ ! -f "$branches_file" ] || [ ! -f "$main_file" ]; then
  printf '%s\n' "$current_branches" >"$branches_file"
  printf '%s\n' "$current_main" >"$main_file"
  exit 0
fi

previous_main=$(cat "$main_file")
deleted=$(comm -23 "$branches_file" <(printf '%s\n' "$current_branches"))
printf '%s\n' "$current_branches" >"$branches_file"
printf '%s\n' "$current_main" >"$main_file"

merged_plans=""
if [ "$previous_main" != "$current_main" ] && git -C "$cwd" merge-base --is-ancestor "$previous_main" "$current_main" 2>/dev/null; then
  merged_plans=$(git -C "$cwd" diff --name-only "$previous_main" "$current_main" -- .claude/plans/active | grep '\.md$')
fi

if [ -z "$deleted" ] && [ -z "$merged_plans" ]; then
  exit 0
fi

plans_dir="$cwd/.claude/plans/active"
[ -d "$plans_dir" ] || exit 0

other_branches=$(printf '%s\n' "$current_branches" | grep -vxF "$main_ref")

messages=""
for f in "$plans_dir"/*.md; do
  [ -e "$f" ] || continue
  rel=${f#"$cwd"/}
  referenced=$(grep -oE '`[a-z]+/[A-Za-z0-9._-]+`' "$f" | tr -d '`' | sort -u)
  deleted_hit=$(comm -12 <(printf '%s\n' "$deleted") <(printf '%s\n' "$referenced"))
  if [ -z "$deleted_hit" ] && ! printf '%s\n' "$merged_plans" | grep -qxF "$rel"; then
    continue
  fi

  pending=""
  while IFS= read -r b; do
    [ -n "$b" ] || continue
    if ! git -C "$cwd" diff --quiet "$main_ref...$b" -- "$rel" 2>/dev/null \
      || printf '%s\n' "$referenced" | grep -qxF "$b"; then
      pending+="$(git -C "$cwd" rev-list --count "$main_ref..$b") $b"$'\n'
    fi
  done <<<"$other_branches"

  unchecked=$(grep -cE '^[[:space:]]*- \[ \]' "$f")
  if [ -z "$pending" ]; then
    messages+="- ${rel}: 完了処理の候補。このplanへの変更・記載ブランチはすべてmainに反映済み。未チェック項目${unchecked}件"$'\n'
  else
    count=$(printf '%s' "$pending" | grep -c .)
    lowest=$(printf '%s' "$pending" | sort -n | head -3 | cut -d' ' -f2- | paste -sd ' ' -)
    messages+="- ${rel}: 未完了。このplanへの未反映の変更または記載を持つローカルブランチ${count}本（スタック下段から: ${lowest}）。未チェック項目${unchecked}件"$'\n'
  fi
done

[ -n "$messages" ] || exit 0

context="mainへのマージまたはローカルブランチの削除を検出した。影響を受けたactive plan:"$'\n'"${messages}完了処理の候補があれば、ユーザーへの完了報告の前にexecution-plan skillの完了処理を行うか、ユーザーに確認すること。"

printf '%s\n' "$context" >&2
exit 2
