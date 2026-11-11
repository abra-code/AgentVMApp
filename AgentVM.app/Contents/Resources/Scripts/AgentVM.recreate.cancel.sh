#!/bin/sh
# AgentVM.recreate.cancel.sh
# Cancel, in the Recreate window: the window closes, and nothing is recreated. Its close handler
# does the rest.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.recreate.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
recreate_is "$window_uuid" || exit 0
"$dialog" "$window_uuid" omc_window omc_terminate_cancel
exit 0
