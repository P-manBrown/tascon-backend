#!/usr/bin/env bash
set -u
. "$(dirname -- "${BASH_SOURCE[0]}")/helpers.sh"
. "$scripts_dir/lib/result.sh"

for pair in merged:0 wait:10 restacked:10 restack_conflict:20 push_check_failed:21 \
  pre_merge_check_failed:22 precondition_failed:23 merge_rejected:24 transient:3; do
  check "exit code of ${pair%%:*}" "${pair##*:}" "$(result_exit_code "${pair%%:*}")"
done
result_exit_code nonsense >/dev/null
check "unknown result word fails" 1 "$?"

check "result line" \
  '{"result":"wait","exit":10,"pr":5,"merged":[],"waiting_on":4,"reason":"PR #4 を待つ"}' \
  "$(emit_result wait 10 5 '[]' 4 'PR #4 を待つ')"
check "result line with nulls" \
  '{"result":"restacked","exit":0,"pr":null,"merged":[],"waiting_on":null,"reason":"r \"q\""}' \
  "$(emit_result restacked 0 null '[]' null 'r "q"')"

finish
