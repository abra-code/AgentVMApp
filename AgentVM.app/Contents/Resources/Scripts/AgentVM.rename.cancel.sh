#!/bin/sh
# AgentVM.rename.cancel.sh
# Cancel, in the Rename window: the window closes, and nothing is renamed. Its close handler
# does the rest.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.rename.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
rename_is "$window_uuid" || exit 0
"$dialog" "$window_uuid" omc_window omc_terminate_cancel
exit 0
