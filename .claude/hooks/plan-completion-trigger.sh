#!/usr/bin/env bash
# PostToolUse (Bash) hook. After `gh pr merge`, judges plan completion with the
# plan-completion Skill scripts and tells Claude (stderr, exit 2) which plans
# need the completion process and which pull request marks need a human.
# Prints nothing and exits 0 for other commands or when nothing needs doing.
set -u

input=$(cat)
command=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
pattern='(^|[;&|(`[:space:]])gh[[:space:]]+pr[[:space:]]+merge([[:space:]]|$)'
printf '%s\n' "$command" | grep -Eq -- "$pattern" || exit 0

hook_dir=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd) || exit 0
scripts="$hook_dir/../skills/plan-completion/scripts"

not_judged() {
  printf '%s\n' "gh pr merge の後に計画の完了を判定できなかった（$1）。後で plan-completion Skill の判定をやり直すこと。" >&2
  exit 2
}

cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
[ -n "$cwd" ] && git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1 || not_judged "git リポジトリの中で実行されていない"
repo=$(cd "$cwd" && gh repo view --json nameWithOwner 2>/dev/null | jq -r '.nameWithOwner // empty')
[ -n "$repo" ] || not_judged "gh repo view でリポジトリを特定できない"

. "$scripts/lib/tempdir.sh" || not_judged "plan-completion Skill のスクリプトが無い"
work=$(make_temp_dir) || not_judged "一時のフォルダを作れない"
trap 'rm -rf "$work"' EXIT

result=$(cd "$work" && bash "$scripts/judge-completion.sh" --repo "$repo")
code=$?
[ "$code" -eq 0 ] || [ "$code" -eq 4 ] || not_judged "judge-completion.sh の終了コード $code"

messages=""
while IFS=$'\x1f' read -r plan completing_pr; do
  [ -n "$plan" ] || continue
  name=${plan##*/}
  found=$(cd "$work" && bash "$scripts/find-completion-pr.sh" --repo "$repo" --plan "${name%.md}")
  find_code=$?
  if [ "$find_code" -ne 0 ]; then
    messages+="- $plan: 完了の処理の PR があるかを確かめられなかった（find-completion-pr.sh の終了コード $find_code）。後で plan-completion Skill の判定をやり直すこと。"$'\n'
  elif [ -z "$found" ]; then
    messages+="- $plan は完了した（完了させた PR: #$completing_pr）。plan-completion Skill で完了の処理を行うこと。"$'\n'
  fi
done < <(printf '%s' "$result" | jq -r '.completed[] | [.plan, (.completing_pr | tostring)] | join("\u001f")')

marks=$(printf '%s' "$result" | jq -r '
  (.missing_marker[] | "- \(.plan): 指す PR（\(.prs | map("#\(.)") | join(", "))）はすべて main にマージ済みだが、✅ の Plan 行が無い"),
  (.unreadable[] | "- #\(.pr): 読めない Plan 行: \(.line)")')
if [ -n "$marks" ]; then
  messages+="次の PR の Related Documents の印を人に知らせ、直してもらうこと（自動で直さない）:"$'\n'"$marks"$'\n'
fi

[ -n "$messages" ] || exit 0
printf '%s' "$messages" >&2
exit 2
