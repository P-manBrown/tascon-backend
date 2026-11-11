# Readers of the index and HEAD shared by the pre-commit checks. Source it
# inside the repository, after setting lib_dir to this directory.

# load_changes: fills change[<path>] with the staged status letter (A, M, D,
# ...) of each path against HEAD (or the empty tree before the first commit).
load_changes() {
  local base st path
  if git rev-parse --verify -q HEAD >/dev/null; then
    base=HEAD
  else
    base=$(git hash-object -t tree /dev/null)
  fi
  declare -gA change=()
  while IFS= read -r -d '' st && IFS= read -r -d '' path; do
    change[$path]=${st:0:1}
  done < <(git diff --cached --no-renames --name-status -z "$base")
}

problems=()
problem() { problems+=("$1: $2"); }

in_index() { git cat-file -e ":$1" 2>/dev/null; }
index_text() { git show ":$1"; }
head_text() { git show "HEAD:$1"; }
# The Markdown readers are the plan-completion skill's markdown.jq.
jq_md() { jq -L "$lib_dir/../../../.claude/skills/plan-completion/scripts/lib" "$@"; }

declare -A anchors_cache=()
# anchors_of <path>: anchors of the headings of an index Markdown file.
anchors_of() {
  if [ -z "${anchors_cache[$1]+set}" ]; then
    anchors_cache[$1]=$(index_text "$1" | jq_md -Rrs 'include "markdown"; md_anchors[]')
  fi
  printf '%s\n' "${anchors_cache[$1]}"
}

# target_problem <path> <anchor>: prints why the target is missing, or nothing.
target_problem() {
  local path=$1 anchor=$2
  if [ -z "$path" ]; then
    echo "points outside the repository"
  elif in_index "$path"; then
    case "$path" in
      *.md)
        if [ -n "$anchor" ] && ! anchors_of "$path" | grep -Fxq -- "$anchor"; then
          echo "has no heading for #$anchor in $path"
        fi
        ;;
    esac
  elif [ -z "$(git ls-files -- "$path/" | head -n 1)" ]; then
    echo "points to $path, which is not in the commit"
  fi
}
