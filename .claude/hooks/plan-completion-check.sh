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

state_dir="$(dirname "$(git -C "$cwd" rev-parse --path-format=absolute --git-common-dir)")/.claude/hook-state/plan-completion"
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

cd "$cwd" || exit 0

gh_failure() {
  trap - EXIT
  printf '%s\n' 'mainへのマージを検出したが、ghが使えないためplanの完了を判定できなかった。' >&2
  exit 2
}

declare -A just_merged=()
while IFS= read -r sha; do
  heads=$(gh api "repos/{owner}/{repo}/commits/$sha/pulls" --jq '.[] | select(.base.ref == "main" and .merged_at != null) | .head.ref' 2>/dev/null) || gh_failure
  while IFS= read -r b; do
    [ -n "$b" ] && just_merged["$b"]=1
  done <<<"$heads"
done < <(git rev-list "$previous_main..$current_main")

messages=""
while IFS= read -r rel; do
  case "$rel" in
    .claude/plans/active/*.md)
      name=${rel#.claude/plans/active/}
      [[ "$name" != */* ]] || continue
      ;;
    *) continue ;;
  esac

  content=$(git show "$main_ref:$rel")
  section=""
  unchecked=false
  while IFS= read -r line; do
    case "$line" in
      '## '*) section=$line; continue ;;
    esac
    if [ "$section" = '## Progress' ] && [[ "$line" == *'- [ ]'* ]]; then
      unchecked=true
    fi
  done <<<"$content"

  "$unchecked" && continue

  slug=${name%.md}
  branches=()
  while IFS= read -r b; do
    [ "$b" != "$main_ref" ] || continue
    while IFS= read -r plan; do
      if [ "$plan" = "$slug" ] || { [[ "$plan" == "$slug":* ]] && [[ "${plan#"$slug":}" =~ ^[0-9]+$ ]]; }; then
        branches+=("$b")
        break
      fi
    done < <(git config --get-all "branch.$b.plan")
  done < <(git for-each-ref --format='%(refname:strip=2)' refs/heads/)

  complete=true
  for b in "${branches[@]}"; do
    [ -z "${just_merged[$b]+yes}" ] || continue
    oids=$(gh pr list --state merged --base main --head "$b" --json headRefOid --jq '.[].headRefOid' 2>/dev/null) || gh_failure
    if [ -z "$oids" ]; then
      complete=false
      continue
    fi
    if tip=$(git rev-parse --verify -q "refs/heads/$b"); then
      if ! printf '%s\n' "$oids" | grep -qxF "$tip"; then
        complete=false
      fi
    fi
  done

  if "$complete"; then
    messages+="- $rel"$'\n'
  fi
done < <(git ls-tree -r --name-only "$main_ref" .claude/plans/active/)

[ -n "$messages" ] || exit 0
printf '%s\n' 'mainへのマージを検出した。次のplanは、planのブランチ（branch.<name>.plan）がすべてmainへマージ済みで、Progressに未チェックがない:' >&2
printf '%s' "$messages" >&2
printf '%s\n' 'execution-plan skillの完了処理（Validation and Acceptanceの確認から）を行うこと。' >&2
exit 2
