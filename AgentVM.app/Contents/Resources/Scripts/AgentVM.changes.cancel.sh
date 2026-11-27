#!/bin/sh
# AgentVM.changes.cancel.sh
# Close in the Session Changes window.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.changes.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
chg_is "$window_uuid" || exit 0
"$dialog" "$window_uuid" omc_window omc_terminate_cancel
exit 0
