#!/usr/bin/env bash
# Usage: check-pr-body.sh --body-file <path>
# Checks the "### Related Documents" section of a pull request body against
# the format in the plan-completion skill. Reads only the given file.
# Output (stdout): one line per problem. With GITHUB_ACTIONS=true, as GitHub
# workflow commands (::error::, ::warning::); otherwise "error: " and
# "warning: " lines.
# Exit: 0 no errors (warnings allowed) / 1 errors found / 2 usage error /
#       3 internal error
set -u

script_dir=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd) || exit 3
lib_dir="$script_dir/lib"

usage() {
  printf '%s\n' "usage: check-pr-body.sh --body-file <path>" >&2
  exit 2
}

body_file=""
while [ $# -gt 0 ]; do
  case "$1" in
    --body-file)
      [ $# -ge 2 ] && [ -z "$body_file" ] || usage
      body_file=$2
      shift 2
      ;;
    *) usage ;;
  esac
done
[ -n "$body_file" ] || usage
if [ ! -f "$body_file" ] || [ ! -r "$body_file" ]; then
  printf '%s\n' "cannot read the body file: $body_file" >&2
  exit 2
fi
command -v jq >/dev/null 2>&1 || { printf '%s\n' "jq is not installed" >&2; exit 3; }
[ -r "$lib_dir/markdown.jq" ] || { printf '%s\n' "cannot read $lib_dir/markdown.jq" >&2; exit 3; }

# Input: the whole body. Output: array of {level, message} in a fixed order:
# the section count, then each line of the sections, then missing lines, then
# N/A mixed with paths.
program='
  include "markdown";
  def problem($level; $message): {level: $level, message: $message};
  def quoted: "\"" + . + "\"";
  related_documents_count as $count
  | if $count == 0 then
      [problem("error"; "no \"### Related Documents\" section; add it with a \"- Plan: <path>\" line and a \"- Spec: <path>\" line")]
    else
      document_lines as $lines
      | [(if $count > 1 then problem("error"; "\($count) \"### Related Documents\" sections; keep exactly one") else empty end),
         ($lines[]
          | if .kind == "other" then
              problem("error"; "not a plan or spec line (\"- Plan: <path>\", \"- ✅ Plan: <path>\" or \"- Spec: <path>\"; write other text in Notes): \(.line | quoted)")
            elif .kind == "Plan" or .kind == "Spec" then
              (if .mark == "🏃" or .mark == "⬜" then
                 problem("warning"; "\(.mark) is an earlier mark; only the plan line of the pull request that completes the plan gets ✅ and the other lines get no mark: \(.line | quoted)")
               else empty end),
              (if .kind == "Spec" and .mark == "✅" then
                 problem("error"; "✅ goes only on plan lines, not on spec lines: \(.line | quoted)")
               else empty end),
              (if .kind == "Plan" and .mark == "✅" and .path == "N/A" then
                 problem("error"; "a plan line with ✅ needs the plan path, not N/A: \(.line | quoted)")
               else empty end),
              (if .kind == "Plan" and (.path | test("^(N/A|docs/design/plans/(active|completed)/[^/]+\\.md)$") | not) then
                 problem("error"; "a plan path is N/A, docs/design/plans/active/<name>.md or docs/design/plans/completed/<name>.md: \(.line | quoted)")
               else empty end),
              (if .kind == "Spec" and .path != "N/A" and (.path | test("^\\.{0,2}/")) then
                 problem("error"; "a spec path is N/A or a path from the repository root, not starting with /, ./ or ../: \(.line | quoted)")
               else empty end)
            else empty
            end),
         (("Plan", "Spec") as $k
          | select(all($lines[]; .kind != $k))
          | problem("error"; "no \"- \($k): <path>\" line; write \"- \($k): N/A\" when there is none")),
         (("Plan", "Spec") as $k
          | [$lines[] | select(.kind == $k) | .path == "N/A"] as $na
          | (if any($na[]; .) and any($na[]; not) then
               problem("error"; "\($k) lines mix N/A with paths; remove the N/A line")
             else empty end),
            (([$na[] | select(.)] | length) as $n
             | if $n > 1 then problem("error"; "\($n) \"- \($k): N/A\" lines; keep one") else empty end))]
    end'

problems=$(jq -Rsc -L "$lib_dir" "$program" <"$body_file") || { printf '%s\n' "failed to check the body" >&2; exit 3; }
printf '%s' "$problems" | jq -r --arg annotate "${GITHUB_ACTIONS:-}" '
  def escape: gsub("%"; "%25") | gsub("\r"; "%0D") | gsub("\n"; "%0A");
  .[] | if $annotate == "true" then "::\(.level)::\(.message | escape)" else "\(.level): \(.message)" end' \
  || { printf '%s\n' "failed to print the problems" >&2; exit 3; }
errors=$(printf '%s' "$problems" | jq '[.[] | select(.level == "error")] | length') \
  || { printf '%s\n' "failed to count the errors" >&2; exit 3; }
[ "$errors" -eq 0 ] || exit 1
exit 0
