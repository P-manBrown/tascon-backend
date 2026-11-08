# make_temp_dir: creates a new empty directory under ${TMPDIR:-/tmp} and
# prints its path. Uses mkdir (fails when the name exists) instead of mktemp,
# retrying with another name. The caller removes it (trap ... EXIT).
make_temp_dir() {
  local base=${TMPDIR:-/tmp} try dir
  for try in 1 2 3 4 5 6 7 8 9 10; do
    dir="$base/plan-completion.$$.$RANDOM$RANDOM.$try"
    if mkdir -m 700 "$dir" 2>/dev/null; then
      printf '%s\n' "$dir"
      return 0
    fi
  done
  printf '%s\n' "could not create a temporary directory under $base" >&2
  return 1
}
