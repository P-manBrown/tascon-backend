#!/usr/bin/env bash
# Fake pre-merge-check.sh: appends the checked-out commit to $FAKE_CHECK_LOG,
# appends a line to the file named by $FAKE_CHECK_TOUCH when it is set, and
# exits with $FAKE_CHECK_EXIT (0 by default).
git rev-parse HEAD >>"${FAKE_CHECK_LOG:?FAKE_CHECK_LOG is not set}"
[ -n "${FAKE_CHECK_TOUCH:-}" ] && printf 'changed\n' >>"$FAKE_CHECK_TOUCH"
exit "${FAKE_CHECK_EXIT:-0}"
