#!/bin/sh
# AgentVM.newbox.cancel.sh
# Cancel, in the New Box window: the window closes, and no box is made. Its close handler does
# the rest. Also the OK of the alert about a box that was made and could not be started.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.newbox.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
newbox_is "$window_uuid" || exit 0
"$dialog" "$window_uuid" omc_window omc_terminate_cancel
exit 0
