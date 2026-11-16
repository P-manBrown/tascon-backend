# Result line shared by merge-stack.sh and restack-stack.sh. Source this file;
# it defines functions only.

# result_exit_code <result>: prints the exit code of a result word; returns 1
# for an unknown word.
result_exit_code() {
  case "$1" in
    merged) printf '0\n' ;;
    wait | restacked) printf '10\n' ;;
    restack_conflict) printf '20\n' ;;
    push_check_failed) printf '21\n' ;;
    pre_merge_check_failed) printf '22\n' ;;
    precondition_failed) printf '23\n' ;;
    merge_rejected) printf '24\n' ;;
    transient) printf '3\n' ;;
    *) return 1 ;;
  esac
}

# emit_result <result> <exit code> <pr number or null> <merged JSON array>
#             <waiting_on number or null> <reason>
# Prints the one-line JSON result.
emit_result() {
  jq -cn --arg result "$1" --argjson exit "$2" --argjson pr "$3" --argjson merged "$4" \
    --argjson waiting "$5" --arg reason "$6" \
    '{result: $result, exit: $exit, pr: $pr, merged: $merged, waiting_on: $waiting, reason: $reason}'
}
