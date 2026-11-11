#!/usr/bin/env bash
# Tests for check-plan-completion.sh in temporary git repositories.
set -u
. "$(dirname -- "${BASH_SOURCE[0]}")/helpers.sh"

ACTIVE_A=.claude/plans/active/a.md
DONE_A=.claude/plans/completed/a.md
active_text=$(cat "$tests_dir/fixtures/plan-active.txt")
completed_text=$(cat "$tests_dir/fixtures/plan-completed.txt")

# edit <text> <old> <new>: the text with the first <old> replaced (literally).
edit() { printf '%s' "${1/"$2"/"$3"}"; }
run_check() {
  out=$(cd "$repo" && bash "$scripts_dir/check-plan-completion.sh" 2>&1)
  code=$?
}
# new_repo: a repository whose HEAD has the active plan a, its spec and the
# documents the completion records point to.
new_repo() {
  new_case
  repo="$case_dir/repo"
  git init -q "$repo"
  put "$ACTIVE_A" "$active_text"
  put .claude/specs/a.md "# 設計 a"
  put docs/decisions/x.md "$(cat "$tests_dir/fixtures/decision.txt")"
  put docs/x.md "# x"
  commit_all "base"
}

# complete_a [completed text]: stage the move of plan a (delete + add).
complete_a() {
  g rm -q "$ACTIVE_A"
  put "$DONE_A" "${1:-$completed_text}"
  g add "$DONE_A"
}

new_repo
mkdir -p "$repo/.claude/plans/completed"
g mv "$ACTIVE_A" "$DONE_A"
put "$DONE_A" "$completed_text"
g add "$DONE_A"
run_check
passes "move that git detects as a rename"

new_repo
complete_a
run_check
passes "move as delete and add"

new_repo
complete_a "$(edit "$completed_text" '- d2: 方式 B を捨てる。理由 2
  - 補足 2
  - 書き写さない: この計画だけの経緯
' '')"
run_check
stops "Decision Log item dropped" "not all kept"

new_repo
complete_a "$(edit "$completed_text" '  - 書き写さない: この計画だけの経緯
' '')"
run_check
stops "Decision Log item without a record" "item 2 needs exactly one"

new_repo
complete_a "$(edit "$completed_text" '`docs/x.md`' '`docs/none.md`')"
run_check
stops "transfer target not in the commit" "docs/none.md, which is not in the commit"

new_repo
complete_a "$(edit "$completed_text" '#方式の選び方' '#無い見出し')"
run_check
stops "transfer target anchor missing" "no heading for #無い見出し"

new_repo
complete_a "$(edit "$completed_text" '書き写さない: この計画だけの経緯' '書き写さない:')"
run_check
stops "empty reason" "empty 書き写さない"

new_repo
complete_a "$(edit "$completed_text" '  - 根拠: 実セッションで gh pr merge の後に知らせが出た
' '')"
run_check
stops "post-merge item without 根拠" "non-empty 根拠"

new_repo
complete_a "$(edit "$completed_text" '結果: 満たす' '結果: たぶん')"
run_check
stops "post-merge item with an unknown 結果" "exactly one 結果"

new_repo
complete_a "$(edit "$completed_text" '- v1: 試しが通る' '- v1: 試しがだいたい通る')"
run_check
stops "Validation and Acceptance rewritten" "Validation and Acceptance differs"

new_repo
g rm -q "$ACTIVE_A"
run_check
stops "active plan only deleted" "deleted without adding"

new_repo
put "$DONE_A" "$completed_text"
g add "$DONE_A"
run_check
stops "completed added while active stays" "is still in the commit"

new_repo
put "$ACTIVE_A" "$(edit "$active_text" '- d3: 名前を決める。理由 3
' '')"
g add "$ACTIVE_A"
run_check
stops "Decision Log items removed before the move" "fewer than the 3 in HEAD"

new_repo
put "$ACTIVE_A" "$(edit "$active_text" '理由 3' '理由 3 を言い直す')"
g add "$ACTIVE_A"
run_check
passes "Decision Log wording changed before the move"

new_repo
complete_a
commit_all "complete a"
put "$DONE_A" "$(edit "$completed_text" '- d3: 名前を決める。理由 3
  - 書き写した: `docs/x.md`、`docs/decisions/x.md`
' '')"
g add "$DONE_A"
run_check
stops "completed plan loses an item" "fewer than the 3 in HEAD"

new_repo
complete_a
commit_all "complete a"
put "$DONE_A" "$(edit "$completed_text" '  - 書き写した: `docs/x.md`、`docs/decisions/x.md`
' '')"
g add "$DONE_A"
run_check
stops "completed plan loses a record line" "item 3 lost its"

new_repo
complete_a
commit_all "complete a"
put "$DONE_A" "$(edit "$completed_text" '  - 根拠: 実セッションで gh pr merge の後に知らせが出た
' '')"
g add "$DONE_A"
run_check
stops "completed plan loses a 根拠 line" "lost its 根拠"

new_repo
complete_a
commit_all "complete a"
put docs/y.md "# y"
put "$DONE_A" "$(edit "$completed_text" '`docs/x.md`、' '`docs/y.md`、')"
g add -A
run_check
passes "completed plan with records: transfer link fixed"

new_repo
put .claude/plans/completed/old.md "$(printf '# old\n\n## Decision Log\n\n- 古い決定\n\n## Notes\n\n[壊れた](missing.md)\n')"
commit_all "old completed plan"
put .claude/plans/completed/old.md "$(printf '# old\n\n## Decision Log\n\n- 古い決定\n\n## Notes\n\n[直した](../../specs/a.md)\n')"
g add -A
run_check
passes "old completed plan without records: link fixed"

new_repo
complete_a
commit_all "complete a"
g rm -q "$DONE_A"
run_check
stops "completed plan deleted" "completed plans are kept"

new_repo
complete_a
g rm -q .claude/specs/a.md
run_check
stops "spec deleted in the move" "specs are not moved or deleted"

new_repo
complete_a "$(edit "$completed_text" '  - 書き写さない: この計画だけの経緯
' '')"
put "$DONE_A" "$completed_text"
run_check
stops "records written in the working tree but not staged" "item 2 needs exactly one"

new_repo
put app/x.rb 'puts 1'
g add -A
run_check
passes "unrelated commit"
check "unrelated commit: no output" "" "$out"

# Without jq the check must fail, not pass silently. An empty PATH has no jq.
new_repo
put app/x.rb 'puts 1'
g add -A
no_jq_bash=$(command -v bash)
empty_path="$case_dir/empty-path"
mkdir "$empty_path"
out=$(cd "$repo" && PATH="$empty_path" "$no_jq_bash" "$scripts_dir/check-plan-completion.sh" 2>&1)
code=$?
stops "jq is missing" "jq is required"

finish
