#!/usr/bin/env bash
# Run Semgrep on the given files with the same Semgrep version, rules and
# arguments as the CI job `semgrep`.
#
# Usage: bash .lefthook/pre-commit/semgrep.sh FILE...
#
# Semgrep comes from .github/requirements/semgrep.txt (--require-hashes) and
# the rules from the semgrep/semgrep-rules commit pinned in
# .github/workflows/ci.yml. Both are cached outside the repository.
set -uo pipefail

[ "$#" -gt 0 ] || exit 0

die() {
  echo "ERROR: $*" >&2
  exit 1
}

repo_root=$(git rev-parse --show-toplevel) || die "Run this script inside the repository."
cd "$repo_root" || die "Cannot change to $repo_root."

requirements=.github/requirements/semgrep.txt
workflow=.github/workflows/ci.yml
rules_url=https://github.com/semgrep/semgrep-rules
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/tascon-backend/semgrep"

[ -f "$requirements" ] || die "$requirements is missing."

rules_sha=$(ruby -ryaml -e '
  steps = YAML.safe_load_file(ARGV[0]).dig("jobs", "semgrep", "steps") || []
  step = steps.find { |s| s.is_a?(Hash) && s.dig("with", "repository") == "semgrep/semgrep-rules" }
  puts step&.dig("with", "ref")
' "$workflow") || die "Could not read $workflow."
[[ "$rules_sha" =~ ^[0-9a-f]{40}$ ]] ||
  die "jobs.semgrep in $workflow must check out semgrep/semgrep-rules at a 40-character commit SHA, got '$rules_sha'."

mkdir -p "$cache_dir" || die "Cannot create $cache_dir."

work_dir=""
cleanup() {
  [ -n "$work_dir" ] && rm -rf "$work_dir"
}
trap cleanup EXIT

# Run git for the rules checkout without the variables that git sets for this
# repository's hooks (GIT_INDEX_FILE and others).
rules_git() {
  (
    # shellcheck disable=SC2046
    unset $(git rev-parse --local-env-vars)
    git -C "$work_dir" "$@"
  )
}

rules_dir="$cache_dir/rules-$rules_sha"
if [ ! -d "$rules_dir/ruby/rails" ]; then
  echo "Fetching the Semgrep rules at $rules_sha ..." >&2
  work_dir=$(mktemp -d "$cache_dir/rules-$rules_sha.tmp.XXXXXX") || die "Cannot create a temporary directory in $cache_dir."
  log="$work_dir.log"
  if ! {
    rules_git init -q &&
      rules_git remote add origin "$rules_url" &&
      rules_git sparse-checkout set ruby/rails &&
      rules_git fetch -q --depth 1 --filter=blob:none origin "$rules_sha" &&
      rules_git checkout -q FETCH_HEAD
  } >"$log" 2>&1; then
    cat "$log" >&2
    rm -f "$log"
    die "Could not fetch the Semgrep rules from $rules_url at $rules_sha. Check the network and commit again."
  fi
  rm -f "$log"
  # mv -T fails instead of moving into the directory when another run placed it first.
  if mv -T "$work_dir" "$rules_dir" 2>/dev/null; then
    work_dir=""
  elif [ -d "$rules_dir/ruby/rails" ]; then
    rm -rf "$work_dir"
    work_dir=""
  else
    die "Could not place the Semgrep rules at $rules_dir."
  fi
fi

python_version=$(python3 -c 'import sys; print("%d.%d.%d" % sys.version_info[:3])') ||
  die "python3 is not available. Rebuild the Dev Container."
read -r requirements_sha _ < <(sha256sum "$requirements")
read -r venv_key _ < <(printf '%s %s\n' "$requirements_sha" "$python_version" | sha256sum)
venv_link="$cache_dir/venv-${venv_key:0:16}"

# A venv cannot be moved after it is built, because its scripts hold its
# absolute path. Build it in a unique directory and publish it with a symlink.
if [ ! -x "$venv_link/bin/semgrep" ]; then
  echo "Installing Semgrep from $requirements ..." >&2
  work_dir=$(mktemp -d "$venv_link.XXXXXX") || die "Cannot create a temporary directory in $cache_dir."
  log="$work_dir.log"
  if ! python3 -m venv "$work_dir" >"$log" 2>&1; then
    cat "$log" >&2
    rm -f "$log"
    die "python3 -m venv failed. Rebuild the Dev Container, or run: sudo apt-get install -y python3-venv"
  fi
  if ! "$work_dir/bin/python" -m pip install --disable-pip-version-check --require-hashes -r "$requirements" >"$log" 2>&1; then
    cat "$log" >&2
    rm -f "$log"
    die "Could not install Semgrep from $requirements. Check the network and commit again."
  fi
  rm -f "$log"
  # ln -sT fails instead of linking inside the directory that another run's link points to.
  if ln -sT "$(basename "$work_dir")" "$venv_link" 2>/dev/null; then
    work_dir=""
  elif [ -x "$venv_link/bin/semgrep" ]; then
    rm -rf "$work_dir"
    work_dir=""
  else
    die "Could not place the Semgrep venv at $venv_link."
  fi
fi

# Scan the repository root like CI and limit the scan to the given files with
# anchored --include patterns. Semgrep skips its default ignores for files given
# as targets, so passing the files as targets would report more than CI.
includes=()
for file in "$@"; do
  includes+=(--include "/$file")
done

"$venv_link/bin/semgrep" scan --config "$rules_dir/ruby/rails" --metrics=off --error "${includes[@]}"
