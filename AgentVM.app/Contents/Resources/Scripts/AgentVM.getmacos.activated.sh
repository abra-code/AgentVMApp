#!/bin/sh
# AgentVM.getmacos.activated.sh
# The Get macOS window came to the front (WINDOW_DID_ACTIVATE_SUBCOMMAND_ID): status and the
# restore files downloaded are read again, and the window is painted. Apple is not asked again:
# Check Again does that.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.getmacos.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
getmacos_is "$window_uuid" || exit 0
getmacos_refresh "$window_uuid"
exit 0
