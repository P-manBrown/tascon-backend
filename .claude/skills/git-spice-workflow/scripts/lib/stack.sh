# Git and git-spice reads shared by merge-stack.sh and restack-stack.sh.
# Source this file; it defines functions only. Functions return 3 when git or
# git-spice failed.

# spice_branches: prints the branches of `git-spice ls --all --json` as one
# JSON array.
spice_branches() {
  local out
  out=$(git-spice ls --all --json 2>/dev/null) || return 3
  jq -c -s '.' <<<"$out" 2>/dev/null || return 3
}

# spice_above <branches JSON> <branch>: prints the branches stacked above the
# branch (following ups), one per line.
spice_above() {
  jq -r --arg b "$2" '
    . as $all
    | def ups($n): $all | map(select(.name == $n)) | (.[0].ups // []) | map(.name);
      def above($n): ups($n)[] as $u | $u, above($u);
      above($b)' <<<"$1"
}

# spice_stack <branches JSON> <branch>: prints {"stack": [names bottom to
# top]} for the stack of the branch (down to main, up through ups), or
# {"error": "<reason>"} when the branch is not tracked, the stack branches, or
# the stack does not reach main.
spice_stack() {
  jq -c --arg b "$2" '
    (map({key: .name, value: .}) | from_entries) as $by
    | def down($n): $by[$n].down.name as $d
        | if $d == null then error("\($n) の土台が分からない")
          elif $d == "main" then [$n]
          else down($d) + [$n]
          end;
      def up($n): ($by[$n].ups // []) as $u
        | if ($u | length) > 1 then error("\($n) の上で枝分かれしている")
          elif ($u | length) == 1 then [$n] + up($u[0].name)
          else [$n]
          end;
      try (
        if $b == "main" or $by[$b] == null then error("\($b) は git-spice で追跡されていない") else . end
        | (down($b) + up($b)[1:]) as $s
        | if any($s[]; ($by[.].ups // []) | length > 1) then error("スタックが枝分かれしている")
          else {stack: $s}
          end
      ) catch {error: .}' <<<"$1"
}

# checked_out_among <branch>...: prints "<branch>（<worktree>）" for each given
# branch other than main that a worktree, the running one included, has
# checked out.
checked_out_among() {
  local list line path="" b name where
  list=$(git worktree list --porcelain) || return 3
  local -a held=()
  while IFS= read -r line; do
    case $line in
      "worktree "*) path=${line#worktree } ;;
      "branch refs/heads/"*) held+=("${line#branch refs/heads/}"$'\t'"$path") ;;
    esac
  done <<<"$list"
  for b in "$@"; do
    [ "$b" = main ] && continue
    for line in "${held[@]}"; do
      name=${line%%$'\t'*}
      where=${line#*$'\t'}
      [ "$name" = "$b" ] && printf '%s（%s）\n' "$b" "$where"
    done
  done
  return 0
}

# one_line <text>: the text with line breaks replaced by ", ".
one_line() { printf '%s' "${1//$'\n'/, }"; }
