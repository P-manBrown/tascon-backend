#!/usr/bin/env bash
set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
output=$(bash "$script_dir/../../.lefthook/pre-commit/check-docs.sh" 2>&1)
status=$?

if [ "$status" -ne 0 ]; then
  echo "$output" >&2
  exit 2
fi

exit 0
