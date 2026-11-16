#!/usr/bin/env bash
set -u
. "$(dirname -- "${BASH_SOURCE[0]}")/helpers.sh"

# run_check <rspec output> <rspec exit code>: runs pre-merge-check.sh where
# bin/bundle prints the output and exits with the code; sets out and code.
run_check() {
  new_dir
  mkdir "$case_dir/bin"
  printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >"%s/args"\nprintf "%%s\\n" %q\nexit %s\n' \
    "$case_dir" "$1" "$2" >"$case_dir/bin/bundle"
  chmod 755 "$case_dir/bin/bundle"
  out=$(cd "$case_dir" && bash "$scripts_dir/pre-merge-check.sh")
  code=$?
}

run_check "10 examples, 0 failures" 0
check "passing rspec" 0 "$code"
check "runs bundle exec rspec" "exec rspec" "$(<"$case_dir/args")"
check "prints the rspec output" yes "$([[ "$out" == *"10 examples, 0 failures"* ]] && echo yes)"

run_check "1 example, 1 failure" 1
check "failing rspec" 1 "$code"

run_check "0 examples, 0 failures, 2 errors occurred outside of examples" 0
check "errors outside of examples with exit 0" 1 "$code"

run_check "could not connect to the database" 2
check "other exit codes become 1" 1 "$code"

finish
