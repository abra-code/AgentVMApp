#!/bin/sh
# AgentVM.discard.cancel.sh
# Cancel, in the Discard Sessions window: the window closes and nothing is discarded. Its close
# handler does the rest.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.discard.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
dsc_is "$window_uuid" || exit 0
"$dialog" "$window_uuid" omc_window omc_terminate_cancel
exit 0
