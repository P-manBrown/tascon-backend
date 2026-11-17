#!/usr/bin/env bash
# Tests for .claude/hooks/plan-completion-trigger.sh. Runs the hook from a
# temporary copy of the layout with a fake gh and fake plan-completion scripts.
# Exit: 0 when every check passes.
set -u
hooks_dir=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd) || exit 1
. "$hooks_dir/../skills/plan-completion/scripts/lib/tempdir.sh"

# Git exports these inside hooks; they would point the test repository elsewhere.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_PREFIX GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES

failures=0
check() {
  if [ "$2" = "$3" ]; then
    printf 'ok   %s\n' "$1"
  else
    printf 'FAIL %s\n  expected: %s\n  actual:   %s\n' "$1" "$2" "$3"
    failures=$((failures + 1))
  fi
}

root=$(make_temp_dir) || exit 1
trap 'rm -rf "$root"' EXIT
mkdir -p "$root/.claude/hooks" "$root/.claude/skills/plan-completion/scripts/lib" "$root/bin" "$root/repo"
cp "$hooks_dir/plan-completion-trigger.sh" "$root/.claude/hooks/"
cp "$hooks_dir/../skills/plan-completion/scripts/lib/tempdir.sh" "$root/.claude/skills/plan-completion/scripts/lib/"
git init -q "$root/repo"

# Fakes: gh answers repo view from $FAKE_REPO_VIEW (fails when empty); the
# scripts print $FAKE_JUDGE_OUT / exit $FAKE_JUDGE_EXIT, and find prints the
# pull request numbers in $FAKE_FIND_<plan name with - as _>.
cat >"$root/bin/gh" <<'EOF'
#!/usr/bin/env bash
[ -n "${FAKE_REPO_VIEW:-}" ] || exit 1
printf '%s\n' "$FAKE_REPO_VIEW"
EOF
cat >"$root/.claude/skills/plan-completion/scripts/judge-completion.sh" <<'EOF'
printf '%s\n' "judge $*" >>"$FAKE_LOG"
[ -n "$(ls -A .)" ] && printf '%s\n' "judge ran in a non-empty directory" >>"$FAKE_LOG"
printf '%s\n' "${FAKE_JUDGE_OUT:-}"
exit "${FAKE_JUDGE_EXIT:-0}"
EOF
cat >"$root/.claude/skills/plan-completion/scripts/find-completion-pr.sh" <<'EOF'
printf '%s\n' "find $*" >>"$FAKE_LOG"
var="FAKE_FIND_$(printf '%s' "$4" | tr '-' '_')"
[ -n "${!var:-}" ] && printf '%s\n' "${!var}"
exit 0
EOF
chmod +x "$root/bin/gh"
export PATH="$root/bin:$PATH" FAKE_LOG="$root/log"
export FAKE_REPO_VIEW='{"nameWithOwner":"o/n"}'
NOTHING='{"completed":[],"missing_marker":[],"unreadable":[],"missing_validation":[]}'

# run_hook <command>: runs the hook with an input of the event in $HOOK_EVENT
# (PostToolUse when unset; PostToolUseFailure adds an error) for that command.
run_hook() {
  : >"$FAKE_LOG"
  jq -cn --arg c "$1" --arg cwd "${HOOK_CWD:-$root/repo}" --arg e "${HOOK_EVENT:-PostToolUse}" \
    '{hook_event_name: $e, tool_name: "Bash", cwd: $cwd, tool_input: {command: $c}}
     + (if $e == "PostToolUseFailure" then {error: "Exit code 1"} else {} end)' \
    | bash "$root/.claude/hooks/plan-completion-trigger.sh" >"$root/stdout" 2>"$root/stderr"
  code=$?
  err=$(cat "$root/stderr")
}

export FAKE_JUDGE_OUT='{"completed":[{"plan":".claude/plans/active/a-b.md","prs":[10,12],"completing_pr":12}],"missing_marker":[],"unreadable":[],"missing_validation":[]}'
for event in PostToolUse PostToolUseFailure; do
  for cmd in 'git-spice downstack merge --branch c' 'git-spice ds m --branch c' 'git-spice branch merge --branch a' 'git-spice b m' 'git-spice stack merge' 'cd x && git-spice downstack merge --branch c' 'x=$(git-spice ds m --branch c)' 'echo `git-spice b m`' 'echo "x; git-spice b m"'; do
    HOOK_EVENT=$event run_hook "$cmd"
    check "fires on $event: $cmd" 2 "$code"
  done
done
case "$err" in
  *".claude/plans/active/a-b.md は完了した（完了させた PR: #12）"*) check "names the completed plan and its pull request" yes yes ;;
  *) check "names the completed plan and its pull request" "message about a-b.md" "$err" ;;
esac
check "judge gets the repository and runs in an empty directory" "judge --repo o/n" "$(sed -n 1p "$FAKE_LOG")"
check "find gets the plan name" "find --repo o/n --plan a-b" "$(sed -n 2p "$FAKE_LOG")"
check "nothing on stdout" "" "$(cat "$root/stdout")"

for event in PostToolUse PostToolUseFailure; do
  for cmd in 'gh pr merge 123 --squash' 'git-spice branch submit' 'git-spice upstack submit --update-only --branch d' 'git-spice upstack restack' 'echo "git-spice downstack merge"' 'gs ds m --branch c' 'git-spice --no-prompt ds m --branch c' 'git-spice b mx' 'git-spice b m-x' 'git-spicex b m' ''; do
    HOOK_EVENT=$event run_hook "$cmd"
    check "does not fire on $event: '$cmd' (exit)" 0 "$code"
    check "does not fire on $event: '$cmd' (output)" "" "$err$(cat "$root/stdout")"
    check "does not fire on $event: '$cmd' (no judge)" "" "$(cat "$FAKE_LOG")"
  done
done

export FAKE_FIND_a_b=40
run_hook 'git-spice downstack merge --branch c'
check "completion pull request exists: exit" 0 "$code"
check "completion pull request exists: no output" "" "$err"
unset FAKE_FIND_a_b

export FAKE_JUDGE_OUT="$NOTHING"
run_hook 'git-spice downstack merge --branch c'
check "nothing to do: exit" 0 "$code"
check "nothing to do: no output" "" "$err"

export FAKE_JUDGE_OUT='{"completed":[],"missing_marker":[{"plan":".claude/plans/active/c.md","prs":[5,6]}],"unreadable":[{"pr":7,"line":"- ✅　Plan: x"}],"missing_validation":[]}'
export FAKE_JUDGE_EXIT=4
run_hook 'git-spice downstack merge --branch c'
check "marks to fix: exit" 2 "$code"
case "$err" in
  *"c.md: 指す PR（#5, #6）"*"#7: 読めない Plan 行: - ✅　Plan: x"*) check "marks to fix: lists them" yes yes ;;
  *) check "marks to fix: lists them" "missing_marker and unreadable lines" "$err" ;;
esac

export FAKE_JUDGE_OUT='{"completed":[{"plan":".claude/plans/active/a-b.md","prs":[10,12],"completing_pr":12}],"missing_marker":[],"unreadable":[],"missing_validation":[{"plan":".claude/plans/active/a-b.md","pr":12,"judged_at":null,"head":"89abcdef0123456789abcdef0123456789abcdef"},{"plan":".claude/plans/active/d.md","pr":14,"judged_at":"fedcba9876543210fedcba9876543210fedcba98","head":"0123456789abcdef0123456789abcdef01234567"}]}'
export FAKE_JUDGE_EXIT=4
run_hook 'git-spice downstack merge --branch c'
check "missing validation: exit" 2 "$code"
case "$err" in
  *"a-b.md は完了した"*"#12（.claude/plans/active/a-b.md）: Testing に計画の確かめの結果が無い"*"#14（.claude/plans/active/d.md）: Testing の計画の確かめの結果は head（0123456789abcdef0123456789abcdef01234567）と違うコミット（fedcba9876543210fedcba9876543210fedcba98）で判定した"*) check "missing validation: lists them after the completed plan" yes yes ;;
  *) check "missing validation: lists them after the completed plan" "completed plan and two missing validation lines" "$err" ;;
esac

export FAKE_JUDGE_OUT='' FAKE_JUDGE_EXIT=3
run_hook 'git-spice downstack merge --branch c'
check "judge exit 3: exit" 2 "$code"
case "$err" in
  *"git-spice のマージのコマンドの後に計画の完了を判定できなかった（judge-completion.sh の終了コード 3）"*) check "judge exit 3: says so" yes yes ;;
  *) check "judge exit 3: says so" "message about exit 3" "$err" ;;
esac
export FAKE_JUDGE_EXIT=0 FAKE_JUDGE_OUT="$NOTHING"

HOOK_CWD="$root" run_hook 'git-spice downstack merge --branch c'
check "outside a git repository: exit" 2 "$code"
case "$err" in
  *"git リポジトリの中で実行されていない"*) check "outside a git repository: says so" yes yes ;;
  *) check "outside a git repository: says so" "message" "$err" ;;
esac

FAKE_REPO_VIEW='' run_hook 'git-spice downstack merge --branch c'
check "gh repo view fails: exit" 2 "$code"

[ "$failures" -eq 0 ]
