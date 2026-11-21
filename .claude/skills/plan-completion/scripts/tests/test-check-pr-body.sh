#!/usr/bin/env bash
# Tests for check-pr-body.sh.
set -u
. "$(dirname -- "${BASH_SOURCE[0]}")/helpers.sh"
unset GITHUB_ACTIONS

A=docs/design/plans/active/x.md
NOT_LINE='not a plan or spec line'
NO_PLAN='no "- Plan: <path>" line'
NO_SPEC='no "- Spec: <path>" line'
NO_SECTION='no "### Related Documents" section'
SPEC_CHECK='✅ goes only on plan lines'
PLAN_CHECK_NA='a plan line with ✅ needs the plan path'
PLAN_PATH='a plan path is N/A'
SPEC_PATH='a spec path is N/A or a path from the repository root'
EARLIER='is an earlier mark'

# write_body <line>...: new case whose body.md is body() with the lines.
write_body() {
  new_case
  body "$@" >"$case_dir/body.md"
}

# write_raw <printf format>: new case whose body.md is the printf output.
write_raw() {
  new_case
  printf "$1" >"$case_dir/body.md"
}

# run_check [NAME=value]...: runs the script on body.md with the variables.
run_check() {
  out=$(env "$@" bash "$scripts_dir/check-pr-body.sh" --body-file "$case_dir/body.md" 2>"$case_dir/err")
  code=$?
}

# has <text>: yes when a line of the output contains the text.
has() { if printf '%s\n' "$out" | grep -qF -- "$1"; then echo yes; else echo no; fi; }

# count <text>: number of output lines that contain the text.
count() { printf '%s\n' "$out" | grep -cF -- "$1"; }

# ok_case <name> <line>...: the lines pass with no output.
ok_case() {
  local name=$1
  shift
  write_body "$@"
  run_check
  check "$name: exit" 0 "$code"
  check "$name: output" "" "$out"
}

# error_case <name> <expected text> <line>...: exit 1 and the text is shown.
error_case() {
  local name=$1 text=$2
  shift 2
  write_body "$@"
  run_check
  check "$name: exit" 1 "$code"
  check "$name: shows the problem" yes "$(has "$text")"
}

# Bodies that follow the rule.
ok_case "template" '<!-- Plan and spec this pull request implements -->' '<!-- Put ✅ only on the plan line -->' "- Plan: $A" '- Spec: docs/design/specs/x.md'
ok_case "completing pull request" "- ✅ Plan: $A" '- Spec: N/A'
ok_case "completion pull request" '- Plan: docs/design/plans/completed/x.md' '- Spec: N/A'
ok_case "no plan and no spec" '- Plan: N/A' '- Spec: N/A'
ok_case "two plan lines" '- Plan: docs/design/plans/active/a.md' '- ✅ Plan: docs/design/plans/active/b.md' '- Spec: N/A'
ok_case "check mark with U+FE0F" "- ✅️ Plan: $A" '- Spec: N/A'
ok_case "template name left as is" '- Plan: docs/design/plans/active/<name>.md' '- Spec: docs/design/specs/<name>.md'
ok_case "blank and whitespace lines" '- Plan: N/A' '' '  ' '	' '- Spec: N/A'
ok_case "lowercase n/a spec path" '- Plan: N/A' '- Spec: n/a'
ok_case "check mark spec line in a fence" '- Plan: N/A' '- Spec: N/A' '```' '- ✅ Spec: N/A' '```'

write_raw '### Summary\r\n\r\nx\r\n\r\n### Related Documents\r\n\r\n- ✅ Plan: docs/design/plans/active/x.md\r\n- Spec: N/A\r\n'
run_check
check "CRLF body: exit" 0 "$code"
check "CRLF body: output" "" "$out"

write_raw '### Summary\n\nfree text - Plan: anything\n\n### Related Documents\n\n- Plan: N/A\n- Spec: N/A\n'
run_check
check "text outside the section: exit" 0 "$code"
check "text outside the section: output" "" "$out"

write_raw '```\n### Related Documents\n- Plan: bad\n```\n\n### Related Documents\n\n- Plan: N/A\n- Spec: N/A\n'
run_check
check "heading in a fence and a real section: exit" 0 "$code"
check "heading in a fence and a real section: output" "" "$out"

# E1: the section.
write_raw '### Summary\n\nx\n'
run_check
check "no section: exit" 1 "$code"
check "no section: only that error" "error: $NO_SECTION; add it with a \"- Plan: <path>\" line and a \"- Spec: <path>\" line" "$out"

write_raw ''
run_check
check "empty body: exit" 1 "$code"
check "empty body: no section" yes "$(has "$NO_SECTION")"

write_raw '```\n### Related Documents\n- Plan: N/A\n- Spec: N/A\n```\n'
run_check
check "heading only in a fence: exit" 1 "$code"
check "heading only in a fence: no section" yes "$(has "$NO_SECTION")"

write_raw '### Related Documents \n\n- Plan: N/A\n- Spec: N/A\n'
run_check
check "heading with trailing space: exit" 1 "$code"
check "heading with trailing space: no section" yes "$(has "$NO_SECTION")"

write_raw '### Related Documents\n\n- Plan: N/A\n- ✅ Spec: N/A\n\n### Related Documents\n\n- ⬜ Plan: docs/design/plans/x.md\n'
run_check
check "two sections: exit" 1 "$code"
check "two sections: count" yes "$(has '2 "### Related Documents" sections; keep exactly one')"
check "two sections: first section checked" yes "$(has "$SPEC_CHECK")"
check "two sections: second section checked" yes "$(has "$PLAN_PATH")"
check "two sections: earlier mark in the second section" yes "$(has "$EARLIER")"
check "two sections: lines read together" yes "$(has 'Plan lines mix N/A with paths')"

# E2: line format.
error_case "full-width space" "$NOT_LINE" '- Plan:　N/A' '- Spec: N/A'
error_case "trailing space" "\"- Plan: N/A \"" '- Plan: N/A ' '- Spec: N/A'
error_case "asterisk bullet" "\"* Plan: N/A\"" '* Plan: N/A' '- Spec: N/A'
error_case "other mark" "\"- ☑ Plan: N/A\"" '- ☑ Plan: N/A' '- Spec: N/A'
error_case "two spaces after the mark" "$NOT_LINE" "- ✅  Plan: $A" '- Spec: N/A'
error_case "lowercase key" "\"- plan: N/A\"" '- plan: N/A' '- Spec: N/A'
error_case "space before the colon" "\"- Plan : N/A\"" '- Plan : N/A' '- Spec: N/A'
error_case "empty path" "$NOT_LINE" '- Plan: ' '- Spec: N/A'
error_case "text after the path" "\"- Plan: $A 段2\"" "- Plan: $A 段2" '- Spec: N/A'
error_case "free text" "\"see the notes\"" '- Plan: N/A' 'see the notes' '- Spec: N/A'
error_case "level 4 heading" "\"#### Plans\"" '#### Plans' '- Plan: N/A' '- Spec: N/A'

write_body '<!-- first' 'second -->' '- Plan: N/A' '- Spec: N/A'
run_check
check "multi-line comment: exit" 1 "$code"
check "multi-line comment: each line" 2 "$(count "$NOT_LINE")"

# E3: plan and spec lines exist.
error_case "no spec line" "$NO_SPEC" '- Plan: N/A'
error_case "no plan line" "$NO_PLAN" '- Spec: N/A'

write_body '- ⬜ Plan: N/A' '- ✅ Spec: N/A'
run_check
check "lines with any mark count: no missing plan" no "$(has "$NO_PLAN")"
check "lines with any mark count: no missing spec" no "$(has "$NO_SPEC")"

# E4 and E5: where ✅ goes.
error_case "check mark on the spec line" "$SPEC_CHECK" '- Plan: N/A' '- ✅ Spec: N/A'
error_case "check mark with N/A" "$PLAN_CHECK_NA" '- ✅ Plan: N/A' '- Spec: N/A'

# E6 and E7: path forms.
error_case "plan directly under plans" "$PLAN_PATH" '- Plan: docs/design/plans/x.md' '- Spec: N/A'
error_case "plan in a subdirectory" "$PLAN_PATH" '- Plan: docs/design/plans/active/sub/x.md' '- Spec: N/A'
error_case "plan not markdown" "$PLAN_PATH" '- Plan: docs/design/plans/active/x.txt' '- Spec: N/A'
error_case "lowercase n/a plan path" "$PLAN_PATH" '- Plan: n/a' '- Spec: N/A'
error_case "plan with an earlier mark" "$PLAN_PATH" '- 🏃 Plan: docs/design/plans/x.md' '- Spec: N/A'
error_case "absolute spec path" "$SPEC_PATH" '- Plan: N/A' '- Spec: /docs/x.md'
error_case "dot spec path" "$SPEC_PATH" '- Plan: N/A' '- Spec: ./docs/x.md'
error_case "parent spec path" "$SPEC_PATH" '- Plan: N/A' '- Spec: ../x.md'

# E8: N/A and paths.
error_case "plan N/A with a path" 'Plan lines mix N/A with paths' '- Plan: N/A' "- Plan: $A" '- Spec: N/A'
error_case "plan N/A twice" '2 "- Plan: N/A" lines; keep one' '- Plan: N/A' '- Plan: N/A' '- Spec: N/A'
error_case "spec N/A with a path" 'Spec lines mix N/A with paths' '- Plan: N/A' '- Spec: N/A' '- Spec: docs/design/specs/x.md'
error_case "spec N/A twice" '2 "- Spec: N/A" lines; keep one' '- Plan: N/A' '- Spec: N/A' '- Spec: N/A'

write_body '- Plan: docs/design/plans/x.md' '- ✅ Spec: N/A'
run_check
check "several errors: exit" 1 "$code"
check "several errors: plan path" yes "$(has "$PLAN_PATH")"
check "several errors: spec check mark" yes "$(has "$SPEC_CHECK")"

# W1: earlier marks.
write_body '- ⬜ Plan: N/A' '- ⬜️ Spec: N/A'
run_check
check "earlier marks: exit" 0 "$code"
check "earlier marks: one warning per line" 2 "$(count "warning: ⬜ $EARLIER")"
check "earlier marks: line as written" yes "$(has '"- ⬜️ Spec: N/A"')"
check "earlier marks: no errors" 0 "$(count 'error: ')"

write_body "- 🏃 Plan: $A" '- Spec: N/A'
run_check
check "running mark: exit" 0 "$code"
check "running mark: warning" "warning: 🏃 $EARLIER; only the plan line of the pull request that completes the plan gets ✅ and the other lines get no mark: \"- 🏃 Plan: $A\"" "$out"

write_body '- ⬜ Plan: docs/design/plans/x.md' '- Spec: N/A'
run_check
check "earlier mark and an error: exit" 1 "$code"
check "earlier mark and an error: warning" yes "$(has "warning: ⬜ $EARLIER")"
check "earlier mark and an error: error" yes "$(has "$PLAN_PATH")"

# Output forms.
write_body '- Plan: N/A' '- ✅ Spec: N/A'
run_check GITHUB_ACTIONS=true
check "annotation error: exit" 1 "$code"
check "annotation error: form" "::error::✅ goes only on plan lines, not on spec lines: \"- ✅ Spec: N/A\"" "$out"

write_body '- ⬜ Plan: N/A' '- Spec: N/A'
run_check GITHUB_ACTIONS=true
check "annotation warning: exit" 0 "$code"
check "annotation warning: form" yes "$(has '::warning::⬜ is an earlier mark')"

write_body '- Plan: 100%' '- Spec: N/A'
run_check GITHUB_ACTIONS=true
check "annotation percent: escaped" yes "$(has '"- Plan: 100%25"')"

write_raw '### Related Documents\n\n- Plan: N/A\rx\n- Spec: N/A\n'
run_check GITHUB_ACTIONS=true
check "annotation CR: escaped" yes "$(has '"- Plan: N/A%0Dx"')"

write_body '- Plan: N/A' '- ✅ Spec: N/A'
run_check GITHUB_ACTIONS=false
check "outside GitHub Actions: plain form" yes "$(has "error: $SPEC_CHECK")"

# Usage and internal errors.
new_case
: >"$case_dir/body.md"
run_usage() {
  out=$(bash "$scripts_dir/check-pr-body.sh" "$@" 2>"$case_dir/err")
  code=$?
}
run_usage
check "no arguments: exit" 2 "$code"
run_usage --body-file
check "no value: exit" 2 "$code"
run_usage --unknown
check "unknown argument: exit" 2 "$code"
run_usage --body-file "$case_dir/body.md" --body-file "$case_dir/body.md"
check "body file twice: exit" 2 "$code"
run_usage --body-file "$case_dir/missing.md"
check "missing body file: exit" 2 "$code"
check "missing body file: reason" yes "$(grep -qF 'cannot read the body file' "$case_dir/err" && echo yes || echo no)"
check "usage error: nothing on stdout" "" "$out"

mkdir "$case_dir/bin"
ln -s "$(command -v dirname)" "$case_dir/bin/dirname"
out=$(PATH="$case_dir/bin" "$BASH" "$scripts_dir/check-pr-body.sh" --body-file "$case_dir/body.md" 2>"$case_dir/err")
code=$?
check "no jq: exit" 3 "$code"
check "no jq: reason" yes "$(grep -qF 'jq is not installed' "$case_dir/err" && echo yes || echo no)"

finish
