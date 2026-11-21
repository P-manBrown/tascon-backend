#!/usr/bin/env bash
# Tests for .claude/hooks/rule-tester-guard.sh. Builds a layout that mimics a
# worktree (.claude/memory is a symlink to a directory outside the repository).
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

base=$(make_temp_dir) || exit 1
trap 'rm -rf "$base"' EXIT
R="$base/repo"
M="$base/main-checkout"
git init -q "$R"
mkdir -p "$M/memory" "$R/.claude/rules" "$R/.claude/plans/active" "$R/docs/design/plans/active"
: >"$M/memory/x.md"
: >"$R/.claude/rules/x.md"
: >"$R/.claude/plans/active/x.md"
: >"$R/.claude/plans/rule-test-fixture.md"
: >"$R/docs/design/plans/active/x.md"
: >"$R/docs/design/plans/rule-test-fixture.md"
: >"$R/README.md"
ln -s "$M/memory" "$R/.claude/memory"
ln -s "$R/.claude/rules/x.md" "$R/link.md"

# run_guard <tool> <path>: prints "deny" when the guard denies, "allow" when it prints nothing.
run_guard() {
  local key=file_path out
  [ "$1" = Read ] || key=path
  out=$(jq -cn --arg cwd "$R" --arg tool "$1" --arg key "$key" --arg path "$2" \
    '{cwd: $cwd, tool_name: $tool, tool_input: {($key): $path}}' \
    | bash "${GUARD:-$hooks_dir/rule-tester-guard.sh}")
  case "$out" in
    *'"permissionDecision": "deny"'*) echo deny ;;
    '') echo allow ;;
    *) echo "unexpected: $out" ;;
  esac
}

check "Read through the .claude/memory symlink" deny "$(run_guard Read "$R/.claude/memory/x.md")"
check "Grep .claude/memory" deny "$(run_guard Grep "$R/.claude/memory")"
check "Glob .claude" deny "$(run_guard Glob "$R/.claude")"
check "Read .claude/plans/active" deny "$(run_guard Read "$R/.claude/plans/active/x.md")"
check "Read docs/design/plans/active" deny "$(run_guard Read "$R/docs/design/plans/active/x.md")"
check "Read .claude/plans fixture" allow "$(run_guard Read "$R/.claude/plans/rule-test-fixture.md")"
check "Read docs/design/plans fixture" allow "$(run_guard Read "$R/docs/design/plans/rule-test-fixture.md")"
check "Read README.md" allow "$(run_guard Read "$R/README.md")"
check "Read a symlink to .claude/rules" deny "$(run_guard Read "$R/link.md")"

# A fixture-named symlink pointing into a forbidden place is not the fixture.
rm "$R/docs/design/plans/rule-test-fixture.md"
ln -s "$R/.claude/rules/x.md" "$R/docs/design/plans/rule-test-fixture.md"
check "Read a fixture-named symlink to .claude/rules" deny "$(run_guard Read "$R/docs/design/plans/rule-test-fixture.md")"

# Outside the repository and not under a forbidden directory of it: out of scope.
check "Read the memory directory directly (outside the repository)" allow "$(run_guard Read "$M/memory/x.md")"

[ "$failures" -eq 0 ]
