#!/usr/bin/env bash
set -u
. "$(dirname -- "${BASH_SOURCE[0]}")/helpers.sh"

head=3e250b74c0ffee00112233445566778899aabbcc

# has <body>: true or false from has_head_record($head).
has() {
  jq -rn -L "$plan_lib_src" -L "$scripts_dir/lib" --arg b "$1" --arg h "$head" \
    'include "pr-body"; $b | has_head_record($h)'
}
body() { printf '### Summary\n\nx\n\n### Testing\n\n%s\n\n### Notes (Optional)\n\n%s\n' "$1" "${2:-none}"; }

check "40 hex digits" true "$(has "$(body "judged at $head")")"
check "first 7 digits" true "$(has "$(body "judged at 3e250b7.")")"
check "upper case" true "$(has "$(body "judged at 3E250B74C0")")"
check "old head only" false "$(has "$(body "judged at 1234567890abcdef")")"
check "6 digits are too short" false "$(has "$(body "judged at 3e250b")")"
check "41 digits are one longer word" false "$(has "$(body "judged at ${head}0")")"
check "glued to letters" false "$(has "$(body "judged atx3e250b74")")"
check "only in Notes" false "$(has "$(body "none" "judged at $head")")"
check "only in a fence" false "$(has "$(body $'```\n'"$head"$'\n```')")"
check "fenced heading does not end the section" true \
  "$(has "$(body $'```\n### Notes\n```\n'"judged at 3e250b74")")"
check "no Testing section" false "$(has $'### Summary\n\n'"$head")"

check "testing_section lines" '["","a",""]' \
  "$(jq -cn -L "$plan_lib_src" -L "$scripts_dir/lib" --arg b $'### Testing\n\na\n\n## Next\nb' \
    'include "pr-body"; [$b | testing_section[] | .line]')"

finish
