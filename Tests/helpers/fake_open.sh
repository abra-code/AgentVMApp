#!/bin/sh
# Tests/helpers/fake_open.sh - /usr/bin/open, recorded instead of run.
#
# lib.agentvm.ui.sh opens Finder and Terminal through open_tool (AGENTVM_APP_OPEN points it
# here). The real one would open windows on the Mac running the tests, and a sandboxed test cannot
# reach Launch Services at all; this appends its arguments, space-joined, to $FAKE_OPEN_LOG, and
# exits with $FAKE_OPEN_STATUS (default 0), so a test can have it fail.
printf '%s\n' "$*" >> "${FAKE_OPEN_LOG:?fake_open: FAKE_OPEN_LOG is not set}"
exit "${FAKE_OPEN_STATUS:-0}"
