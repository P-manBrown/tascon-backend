#!/usr/bin/env bash
# Tests for check-links.sh in temporary git repositories.
set -u
. "$(dirname -- "${BASH_SOURCE[0]}")/helpers.sh"

run_check() {
  out=$(cd "$repo" && bash "$scripts_dir/check-links.sh" 2>&1)
  code=$?
}

# new_repo: a repository whose HEAD has a decision file to link to.
new_repo() {
  new_case
  repo="$case_dir/repo"
  git init -q "$repo"
  put docs/decisions/x.md "$(cat "$tests_dir/fixtures/decision.txt")"
  commit_all "base"
}

new_repo
put docs/z.md '[壊れた](../missing.md)'
g add -A
run_check
stops "broken link in a changed Markdown file" "../missing.md"

new_repo
put docs/z.md '[見出し](decisions/x.md#無い)'
g add -A
run_check
stops "broken heading link" "no heading for #無い"

new_repo
put docs/z.md "$(printf '%s\n' '`[a](missing.md)`' '```' '[a](missing.md)' '```' '[外](https://example.com/missing)' '[自分](#z)' '' '# z')"
g add -A
run_check
passes "code, external URLs and own headings"

new_repo
put docs/日本.md '# 日本'
put docs/z.md '[日本](%E6%97%A5%E6%9C%AC.md)'
g add -A
run_check
passes "percent-encoded link"

new_repo
put docs/y.md '# y'
put docs/z.md '[y](y.md)'
commit_all "y and z"
g rm -q docs/y.md
run_check
stops "deleting a file that an unchanged file links to" "which this commit deletes"

new_repo
put docs/日本.md '# 日本'
put docs/z.md '[日本](%E6%97%A5%E6%9C%AC.md)'
commit_all "nihon and z"
g rm -q docs/日本.md
run_check
stops "deleting a file that an unchanged file links to by a percent-encoded link" "which this commit deletes"

new_case
repo="$case_dir/repo"
git init -q "$repo"
put README.md '# r'
put docs/a.md '[r](../README.md)'
g add -A
run_check
passes "first commit without HEAD"

new_repo
put app/x.rb 'puts 1'
g add -A
run_check
passes "unrelated commit"
check "unrelated commit: no output" "" "$out"

# Without jq the check must fail, not pass silently. An empty PATH has no jq.
new_repo
put app/x.rb 'puts 1'
g add -A
no_jq_bash=$(command -v bash)
empty_path="$case_dir/empty-path"
mkdir "$empty_path"
out=$(cd "$repo" && PATH="$empty_path" "$no_jq_bash" "$scripts_dir/check-links.sh" 2>&1)
code=$?
stops "jq is missing" "jq is required"

finish
