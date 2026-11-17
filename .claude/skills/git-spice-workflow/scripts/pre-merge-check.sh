#!/usr/bin/env bash
# Usage: pre-merge-check.sh
# Runs this repository's checks before merging, in the current directory
# (the root of the worktree to check). Prints the rspec output.
# Exit: 0 when `bin/bundle exec rspec` exits 0 and its output does not say
#       "errors occurred outside of examples" / 1 otherwise
set -u
out=$(bin/bundle exec rspec 2>&1)
code=$?
printf '%s\n' "$out"
[ "$code" -eq 0 ] || exit 1
[[ "$out" == *"errors occurred outside of examples"* ]] && exit 1
exit 0
