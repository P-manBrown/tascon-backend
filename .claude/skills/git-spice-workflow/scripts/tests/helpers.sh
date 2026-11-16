# Helpers sourced by the test-*.sh files. Not a test file itself.
tests_dir=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
scripts_dir=$(dirname -- "$tests_dir")
plan_lib_src=$(CDPATH='' cd -- "$scripts_dir/../../plan-completion/scripts/lib" && pwd)

# Tests run from lefthook's pre-commit too, where git exports variables that
# would point the temporary repositories at the real one.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_PREFIX GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
export MERGE_STACK_POLL_INTERVAL=0 MERGE_STACK_POLL_TIMEOUT=1
export PATH="$tests_dir/fake-bin:$PATH"

failures=0

# check <name> <expected> <actual>
check() {
  if [ "$2" = "$3" ]; then
    printf 'ok   %s\n' "$1"
  else
    printf 'FAIL %s\n  expected: %s\n  actual:   %s\n' "$1" "$2" "$3"
    failures=$((failures + 1))
  fi
}

finish() {
  [ "$failures" -eq 0 ]
  exit $?
}

trap '[ -n "${case_dir:-}" ] && rm -rf "$case_dir"' EXIT

# new_dir: replaces case_dir with a fresh temporary directory and resets the
# fake gh and git-spice answers and logs.
new_dir() {
  [ -n "${case_dir:-}" ] && rm -rf "$case_dir"
  case_dir=$(mktemp -d) || exit 1
  export FAKE_GH_DIR="$case_dir/gh" FAKE_GH_LOG="$case_dir/gh.log"
  export FAKE_GS_DIR="$case_dir/gs" FAKE_GS_LOG="$case_dir/gs.log"
  export FAKE_CHECK_LOG="$case_dir/check.log"
  unset FAKE_CHECK_EXIT FAKE_CHECK_TOUCH
  mkdir "$FAKE_GH_DIR" "$FAKE_GS_DIR" "$case_dir/tmp"
  : >"$FAKE_GH_LOG"
  : >"$FAKE_GS_LOG"
  : >"$FAKE_CHECK_LOG"
}

# logged <log file> <text>: yes when a line of the log contains the text.
logged() {
  local line
  while IFS= read -r line; do
    [[ "$line" == *"$2"* ]] && { echo yes; return; }
  done <"$1"
  echo no
}

# install_scripts: copies the scripts under $case_dir/skills/ the way they sit
# in the repository, with the fake pre-merge-check.sh next to merge-stack.sh.
install_scripts() {
  inst="$case_dir/skills/git-spice-workflow/scripts"
  mkdir -p "$inst" "$case_dir/skills/plan-completion/scripts/lib"
  cp -R "$scripts_dir/lib" "$inst/"
  cp "$scripts_dir/restack-stack.sh" "$inst/"
  [ -f "$scripts_dir/merge-stack.sh" ] && cp "$scripts_dir/merge-stack.sh" "$inst/"
  cp "$tests_dir/fakes/pre-merge-check.sh" "$inst/pre-merge-check.sh"
  cp "$plan_lib_src/markdown.jq" "$case_dir/skills/plan-completion/scripts/lib/"
}

# make_repo: a bare remote, the clone "work" with main checked out (like the
# main checkout), the stack main <- feat/a <- feat/b pushed, refs/spice/data,
# and the worktree "merge" detached at origin/main.
make_repo() {
  remote="$case_dir/remote.git"
  work="$case_dir/work"
  merge_wt="$case_dir/merge"
  git init -q --bare -b main "$remote"
  git clone -q "$remote" "$work" 2>/dev/null
  git -C "$work" commit -q --allow-empty -m init
  printf 'base\n' >"$work/f.txt"
  git -C "$work" add f.txt
  git -C "$work" commit -q -m base
  git -C "$work" switch -q -c feat/a
  printf 'a\n' >"$work/a.txt"
  git -C "$work" add a.txt
  git -C "$work" commit -q -m a
  git -C "$work" switch -q -c feat/b
  printf 'b\n' >"$work/b.txt"
  git -C "$work" add b.txt
  git -C "$work" commit -q -m b
  git -C "$work" switch -q main
  git -C "$work" push -q origin main feat/a feat/b
  git -C "$work" update-ref refs/spice/data "$(git -C "$work" rev-parse main)"
  git -C "$work" worktree add -q --detach "$merge_wt" origin/main
  sha_main=$(git -C "$work" rev-parse main)
  sha_a=$(git -C "$work" rev-parse feat/a)
  sha_b=$(git -C "$work" rev-parse feat/b)
  sha_data=$(git -C "$work" rev-parse refs/spice/data)
}

# new_case: new_dir, the scripts and the repository.
new_case() {
  new_dir
  install_scripts
  make_repo
}

# spice_ls <JSON line>...: the answer of `git-spice ls --all --json`.
spice_ls() { printf '%s\n' "$@" >"$FAKE_GS_DIR/ls"; }

# default_ls: feat/a (#1) <- feat/b (#2), both pushed and in sync.
default_ls() {
  spice_ls \
    '{"name":"feat/a","down":{"name":"main"},"ups":[{"name":"feat/b"}],"change":{"id":"#1"},"push":{"ahead":0,"behind":0}}' \
    '{"name":"feat/b","down":{"name":"feat/a"},"change":{"id":"#2"},"push":{"ahead":0,"behind":0}}' \
    '{"name":"main","ups":[{"name":"feat/a"}]}'
}

# gs_hook <key> <bash code>: what the fake git-spice runs for the key.
gs_hook() { printf '%s\n' "$2" >"$FAKE_GS_DIR/$1.sh"; }

# advance_main <file> <content>: a new commit on the remote main.
advance_main() {
  git -C "$work" switch -q main
  printf '%s\n' "$2" >"$work/$1"
  git -C "$work" add "$1"
  git -C "$work" commit -q -m "main $1"
  git -C "$work" push -q origin main
}

# sync_hook: `git-spice repo sync` brings the local main to origin/main.
sync_hook() { gs_hook repo_sync 'git fetch -q origin && git update-ref refs/heads/main refs/remotes/origin/main'; }

# restack_hook: `git-spice stack restack` rebases feat/a on main and feat/b
# on feat/a in the running worktree, leaving feat/b checked out like git-spice.
restack_hook() {
  gs_hook stack_restack 'git switch -q feat/a && git rebase -q main && git switch -q feat/b && git rebase -q feat/a'
}

# json <field>: a field of the last result line in $out.
json() { jq -r ".$1" <<<"$out"; }

# head_state <dir>: "branch <name>" or "detached <sha>" of a worktree.
head_state() {
  local b
  if b=$(git -C "$1" symbolic-ref -q --short HEAD); then echo "branch $b"; else echo "detached $(git -C "$1" rev-parse HEAD)"; fi
}

# run_restack <dir> <args>...: runs the installed restack-stack.sh in the dir.
run_restack() {
  local dir=$1
  shift
  out=$(cd "$dir" && bash "$inst/restack-stack.sh" "$@")
  code=$?
}

REPO=o/n

# answer <key> <body> [exit code]: an answer of the fake gh.
answer() {
  printf '%s\n' "$2" >"$FAKE_GH_DIR/$1"
  [ -n "${3:-}" ] && printf '%s\n' "$3" >"$FAKE_GH_DIR/$1.exit"
  return 0
}

# pr_json <number> <head> <base> <oid> [jq update]: a `gh pr view` answer of
# an open, approved pull request whose checks passed, changed by the update.
pr_json() {
  jq -cn --argjson n "$1" --arg h "$2" --arg b "$3" --arg o "$4" \
    '{number: $n, state: "OPEN", isDraft: false, reviewDecision: "APPROVED",
      statusCheckRollup: [{__typename: "CheckRun", name: "ci", status: "COMPLETED", conclusion: "SUCCESS"}],
      headRefName: $h, headRefOid: $o, baseRefName: $b, mergeStateStatus: "CLEAN", body: ""}' \
    | jq -c "${5:-.}"
}

# stack_answer <asked number> <number>...: the stacks answer for the asked
# pull request (the numbers bottom to top; none for "not in a stack").
stack_answer() {
  local asked=$1
  shift
  if [ $# -eq 0 ]; then
    answer "GET_repos_o_n_stacks_pull_request_$asked" '[]'
  else
    answer "GET_repos_o_n_stacks_pull_request_$asked" \
      "$(jq -cn '[{pull_requests: [$ARGS.positional[] | {number: tonumber}]}]' --args "$@")"
  fi
}

# two_prs [jq update for #1] [jq update for #2]: #1 feat/a <- #2 feat/b.
two_prs() {
  answer repo-view '{"nameWithOwner":"o/n"}'
  stack_answer 2 1 2
  answer pr-view-1 "$(pr_json 1 feat/a main "$sha_a" "${1:-.}")"
  answer pr-view-2 "$(pr_json 2 feat/b feat/a "$sha_b" "${2:-.}")"
  default_ls
}

# run_merge [args]: runs the installed merge-stack.sh in the merge worktree
# (default --pr 2).
run_merge() {
  [ $# -eq 0 ] && set -- --pr 2
  out=$(cd "$merge_wt" && TMPDIR="$case_dir/tmp" bash "$inst/merge-stack.sh" "$@")
  code=$?
}

# gh_called <text>: yes when a fake gh call contains the text.
gh_called() { logged "$FAKE_GH_LOG" "$1"; }
