#!/bin/sh
# AgentVM.logs.activated.sh
# The Where the Logs Are window came to the front (WINDOW_DID_ACTIVATE_SUBCOMMAND_ID): status is
# read again, since a box may have been made or deleted meanwhile, and the window is painted.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.logs.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
logs_is "$window_uuid" || exit 0
logs_refresh "$window_uuid"
exit 0
