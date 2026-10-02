#!/bin/sh
# AgentVM.access.cancel.sh
# Close, in an image's Full Disk Access guide: the window closes, and nothing is started or
# stopped. Its close handler does the rest.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.access.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
"$dialog" "$window_uuid" omc_window omc_terminate_cancel
exit 0
