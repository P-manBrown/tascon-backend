# GitHub access shared by merge-stack.sh. Source this file; it defines
# functions only. Functions return 3 when gh failed or answered something
# unexpected.

api_version_header='X-GitHub-Api-Version: 2026-03-10'
pr_fields=number,state,isDraft,reviewDecision,statusCheckRollup,headRefName,headRefOid,baseRefName,mergeStateStatus,body

# gh_repo: prints <owner>/<name> of the current repository.
gh_repo() {
  local out name
  out=$(gh repo view --json nameWithOwner 2>/dev/null) || return 3
  name=$(jq -r '.nameWithOwner // empty' <<<"$out" 2>/dev/null)
  [[ "$name" =~ ^[[:alnum:]_.-]+/[[:alnum:]_.-]+$ ]] || return 3
  printf '%s\n' "$name"
}

# gh_stack_numbers <repo> <number>: prints the pull request numbers of the
# stack that contains the pull request, bottom to top, one per line. A pull
# request outside any stack (empty answer or 404) is printed alone.
gh_stack_numbers() {
  local out
  if ! out=$(gh api -H "$api_version_header" "repos/$1/stacks?pull_request=$2" 2>/dev/null); then
    jq -e '(.status | tostring) == "404"' <<<"$out" >/dev/null 2>&1 || return 3
    out='[]'
  fi
  jq -r --argjson n "$2" '
    if type != "array" then error("unexpected shape")
    elif length == 0 then $n
    else .[0].pull_requests[].number
    end' <<<"$out" 2>/dev/null || return 3
}

# gh_pr <number>: prints the pull request as one JSON line.
gh_pr() {
  local out
  out=$(gh pr view "$1" --json "$pr_fields" 2>/dev/null) || return 3
  jq -c -e 'select(type == "object" and (.number | type) == "number")' <<<"$out" 2>/dev/null || return 3
}
