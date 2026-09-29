#!/bin/sh
# Tests/helpers/fake_sleep.sh - the poll loop's wait, recorded instead of waited.
#
# AGENTVM_APP_SLEEP points lib.agentvm.ui.sh here. Each call appends its seconds to
# $FAKE_SLEEP_LOG and returns at once. With FAKE_SLEEP_TAKE_TOKEN set, it also does what a newer
# poll loop does while the old one sleeps: it takes the window's poll token.
printf '%s\n' "$*" >> "${FAKE_SLEEP_LOG:?fake_sleep: FAKE_SLEEP_LOG is not set}"
if [ -n "${FAKE_SLEEP_TAKE_TOKEN:-}" ]; then
    "$OMC_OMC_SUPPORT_PATH/pasteboard" "agentvm_poll_$OMC_ACTIONUI_WINDOW_UUID" set "$FAKE_SLEEP_TAKE_TOKEN"
fi
exit 0
