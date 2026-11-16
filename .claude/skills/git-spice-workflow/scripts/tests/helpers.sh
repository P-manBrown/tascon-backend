# Helpers sourced by the test-*.sh files. Not a test file itself.
tests_dir=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
scripts_dir=$(dirname -- "$tests_dir")
plan_lib_src=$(CDPATH='' cd -- "$scripts_dir/../../plan-completion/scripts/lib" && pwd)

# Tests run from lefthook's pre-commit too, where git exports variables that
# would point the temporary repositories at the real one.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_PREFIX GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
export MERGE_STACK_POLL_INTERVAL=0 MERGE_STACK_POLL_TIMEOUT=1
export PATH="$tests_dir/fake-bin:$PATH"

failures=0

# check <name> <expected> <actual>
check() {
  if [ "$2" = "$3" ]; then
    printf 'ok   %s\n' "$1"
  else
    printf 'FAIL %s\n  expected: %s\n  actual:   %s\n' "$1" "$2" "$3"
    failures=$((failures + 1))
  fi
}

finish() {
  [ "$failures" -eq 0 ]
  exit $?
}

trap '[ -n "${case_dir:-}" ] && rm -rf "$case_dir"' EXIT

# new_dir: replaces case_dir with a fresh temporary directory and resets the
# fake gh and git-spice answers and logs.
new_dir() {
  [ -n "${case_dir:-}" ] && rm -rf "$case_dir"
  case_dir=$(mktemp -d) || exit 1
  export FAKE_GH_DIR="$case_dir/gh" FAKE_GH_LOG="$case_dir/gh.log"
  export FAKE_GS_DIR="$case_dir/gs" FAKE_GS_LOG="$case_dir/gs.log"
  export FAKE_CHECK_LOG="$case_dir/check.log"
  unset FAKE_CHECK_EXIT FAKE_CHECK_TOUCH
  mkdir "$FAKE_GH_DIR" "$FAKE_GS_DIR"
  : >"$FAKE_GH_LOG"
  : >"$FAKE_GS_LOG"
  : >"$FAKE_CHECK_LOG"
}

# logged <log file> <text>: yes when a line of the log contains the text.
logged() {
  local line
  while IFS= read -r line; do
    [[ "$line" == *"$2"* ]] && { echo yes; return; }
  done <"$1"
  echo no
}
