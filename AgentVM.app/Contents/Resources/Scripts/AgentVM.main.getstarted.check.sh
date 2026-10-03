#!/bin/sh
# AgentVM.main.getstarted.check.sh
# Check Again, beside "This Mac can run boxes" in Get started: agent-vm, doctor and the lists are
# read again, and the window is painted.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
main_refresh "$window_uuid" full
exit 0
