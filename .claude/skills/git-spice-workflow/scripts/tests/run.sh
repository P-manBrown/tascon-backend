#!/usr/bin/env bash
# Runs every test-*.sh next to this file. Exit code: the number of test files
# that failed (0 when all pass).
set -u
dir=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd) || exit 1
failed=0
for test_file in "$dir"/test-*.sh; do
  [ -f "$test_file" ] || continue
  printf '== %s\n' "${test_file##*/}"
  bash "$test_file" || failed=$((failed + 1))
done
printf '%s test file(s) failed\n' "$failed"
exit "$failed"
