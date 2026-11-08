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
NOTHING='{"completed":[],"missing_marker":[],"unreadable":[]}'

# run_hook <command>: runs the hook with a PostToolUse input for that command.
run_hook() {
  : >"$FAKE_LOG"
  jq -cn --arg c "$1" --arg cwd "${HOOK_CWD:-$root/repo}" \
    '{hook_event_name: "PostToolUse", tool_name: "Bash", cwd: $cwd, tool_input: {command: $c}}' \
    | bash "$root/.claude/hooks/plan-completion-trigger.sh" >"$root/stdout" 2>"$root/stderr"
  code=$?
  err=$(cat "$root/stderr")
}

export FAKE_JUDGE_OUT='{"completed":[{"plan":".claude/plans/active/a-b.md","prs":[10,12],"completing_pr":12}],"missing_marker":[],"unreadable":[]}'
for cmd in 'gh pr merge 12 --squash --match-head-commit 0123abc' 'cd x && gh pr merge 3' 'x=$(gh pr merge 3)' 'echo `gh pr merge 3`' 'echo "x; gh pr merge 3"'; do
  run_hook "$cmd"
  check "fires on: $cmd" 2 "$code"
done
case "$err" in
  *".claude/plans/active/a-b.md は完了した（完了させた PR: #12）"*) check "names the completed plan and its pull request" yes yes ;;
  *) check "names the completed plan and its pull request" "message about a-b.md" "$err" ;;
esac
check "judge gets the repository and runs in an empty directory" "judge --repo o/n" "$(sed -n 1p "$FAKE_LOG")"
check "find gets the plan name" "find --repo o/n --plan a-b" "$(sed -n 2p "$FAKE_LOG")"
check "nothing on stdout" "" "$(cat "$root/stdout")"

for cmd in 'gh pr view 3' 'ghx pr merge' 'gh pr mergeX' 'echo "gh pr merge"' ''; do
  run_hook "$cmd"
  check "does not fire on: '$cmd' (exit)" 0 "$code"
  check "does not fire on: '$cmd' (output)" "" "$err$(cat "$root/stdout")"
  check "does not fire on: '$cmd' (no judge)" "" "$(cat "$FAKE_LOG")"
done

export FAKE_FIND_a_b=40
run_hook 'gh pr merge 12 --squash'
check "completion pull request exists: exit" 0 "$code"
check "completion pull request exists: no output" "" "$err"
unset FAKE_FIND_a_b

export FAKE_JUDGE_OUT="$NOTHING"
run_hook 'gh pr merge 12 --squash'
check "nothing to do: exit" 0 "$code"
check "nothing to do: no output" "" "$err"

export FAKE_JUDGE_OUT='{"completed":[],"missing_marker":[{"plan":".claude/plans/active/c.md","prs":[5,6]}],"unreadable":[{"pr":7,"line":"- ✅　Plan: x"}]}'
export FAKE_JUDGE_EXIT=4
run_hook 'gh pr merge 12 --squash'
check "marks to fix: exit" 2 "$code"
case "$err" in
  *"c.md: 指す PR（#5, #6）"*"#7: 読めない Plan 行: - ✅　Plan: x"*) check "marks to fix: lists them" yes yes ;;
  *) check "marks to fix: lists them" "missing_marker and unreadable lines" "$err" ;;
esac

export FAKE_JUDGE_OUT='' FAKE_JUDGE_EXIT=3
run_hook 'gh pr merge 12 --squash'
check "judge exit 3: exit" 2 "$code"
case "$err" in
  *"判定できなかった（judge-completion.sh の終了コード 3）"*) check "judge exit 3: says so" yes yes ;;
  *) check "judge exit 3: says so" "message about exit 3" "$err" ;;
esac
export FAKE_JUDGE_EXIT=0 FAKE_JUDGE_OUT="$NOTHING"

HOOK_CWD="$root" run_hook 'gh pr merge 12 --squash'
check "outside a git repository: exit" 2 "$code"
case "$err" in
  *"git リポジトリの中で実行されていない"*) check "outside a git repository: says so" yes yes ;;
  *) check "outside a git repository: says so" "message" "$err" ;;
esac

FAKE_REPO_VIEW='' run_hook 'gh pr merge 12 --squash'
check "gh repo view fails: exit" 2 "$code"

[ "$failures" -eq 0 ]
