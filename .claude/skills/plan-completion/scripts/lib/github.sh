# Read-only GitHub queries shared by judge-completion.sh and
# find-completion-pr.sh. Source this file; it defines functions only.
# Every function returns 0 on success and 3 when the query did not complete
# (gh missing, not authenticated, non-zero exit, not JSON, wrong shape).

# gh_read <endpoint>
# Prints the JSON response of `gh api <endpoint>`. Returns 4 instead of 3 when
# GitHub answered 404, so callers can tell "absent" from "failed".
gh_read() {
  local endpoint=$1 out code
  command -v gh >/dev/null 2>&1 || { printf '%s\n' "gh is not installed" >&2; return 3; }
  out=$(gh api "$endpoint" 2>/dev/null)
  code=$?
  if [ "$code" -ne 0 ]; then
    if printf '%s' "$out" | jq -e '(type == "object") and ((.status | tostring) == "404")' >/dev/null 2>&1; then
      return 4
    fi
    printf '%s\n' "gh api $endpoint failed with exit code $code" >&2
    return 3
  fi
  if ! printf '%s' "$out" | jq -e . >/dev/null 2>&1; then
    printf '%s\n' "gh api $endpoint did not return JSON" >&2
    return 3
  fi
  printf '%s\n' "$out"
}

# gh_pull_pages <repo> <state>
# Reads every page of the pull requests with the given state (all or open),
# oldest first, and prints one compact JSON array per page whose elements are
# {number, state, merged_at, base, body}.
gh_pull_pages() {
  local repo=$1 state=$2 page=1 out count
  while :; do
    out=$(gh_read "repos/$repo/pulls?state=$state&sort=created&direction=asc&per_page=100&page=$page")
    case $? in
      0) ;;
      4)
        printf '%s\n' "pulls page $page of $repo was not found (check the repository name and access)" >&2
        return 3
        ;;
      *) return 3 ;;
    esac
    if ! out=$(printf '%s' "$out" | jq -c '
        if type == "array" and all(.[]; type == "object" and (.number | type) == "number" and (.base.ref | type) == "string")
        then [.[] | {number, state, merged_at, base: .base.ref, body: (.body // "")}]
        else error("unexpected shape")
        end' 2>/dev/null); then
      printf '%s\n' "pulls page $page has an unexpected shape" >&2
      return 3
    fi
    printf '%s\n' "$out"
    count=$(printf '%s' "$out" | jq 'length')
    [ "$count" -ge 100 ] || return 0
    page=$((page + 1))
  done
}
