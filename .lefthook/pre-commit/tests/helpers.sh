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
g() { git -C "$repo" "$@"; }
put() {
  mkdir -p "$repo/$(dirname -- "$1")"
  printf '%s\n' "$2" >"$repo/$1"
}
commit_all() {
  g add -A
  g -c user.name=test -c user.email=test@example.com -c commit.gpgsign=false commit -q --no-verify -m "$1"
}
# stops <name> <text the output must contain>
stops() {
  check "$1: exit" 1 "$code"
  case "$out" in
    *"$2"*) check "$1: reason" found found ;;
    *) check "$1: reason" "$2" "$out" ;;
  esac
}
passes() {
  check "$1: exit" 0 "$code"
  [ "$code" -eq 0 ] || printf '%s\n' "$out"
}

trap '[ -n "${case_dir:-}" ] && rm -rf "$case_dir"' EXIT
