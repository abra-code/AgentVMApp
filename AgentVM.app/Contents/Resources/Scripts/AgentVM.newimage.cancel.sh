#!/bin/sh
# AgentVM.newimage.cancel.sh
# Cancel, in the New Image window: the window closes, and nothing is built. Its close handler
# does the rest.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.newimage.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
"$dialog" "$window_uuid" omc_window omc_terminate_cancel
exit 0
