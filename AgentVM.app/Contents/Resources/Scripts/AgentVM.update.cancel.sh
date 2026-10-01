#!/bin/sh
# AgentVM.update.cancel.sh
# Cancel, in an image's update window: the window closes, and nothing is started. Its close
# handler does the rest.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.update.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
"$dialog" "$window_uuid" omc_window omc_terminate_cancel
exit 0
