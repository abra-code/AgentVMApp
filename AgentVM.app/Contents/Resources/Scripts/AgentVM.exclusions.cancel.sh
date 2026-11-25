#!/bin/sh
# AgentVM.exclusions.cancel.sh
# Cancel, in the Exclusions window: the window closes, and the saved list stays as it was. Its
# close handler does the rest.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.exclusions.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
excl_is "$window_uuid" || exit 0
"$dialog" "$window_uuid" omc_window omc_terminate_cancel
exit 0
