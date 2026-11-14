# Helpers sourced by the test-*.sh files. Not a test file itself.
tests_dir=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
scripts_dir=$(dirname -- "$tests_dir")

# Tests run from lefthook's pre-commit too, where git exports variables that
# would point the temporary repositories at the real one.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_PREFIX GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES

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

# new_case: fresh temporary directory in $case_dir.
new_case() {
  [ -n "${case_dir:-}" ] && rm -rf "$case_dir"
  case_dir=$(mktemp -d) || exit 1
}
trap '[ -n "${case_dir:-}" ] && rm -rf "$case_dir"' EXIT
