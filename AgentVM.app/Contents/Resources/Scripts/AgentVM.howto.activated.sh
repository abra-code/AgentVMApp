#!/bin/sh
# AgentVM.howto.activated.sh
# The How to Use a Box window came to the front (WINDOW_DID_ACTIVATE_SUBCOMMAND_ID): status is
# read again, since an image or a box may have been made meanwhile, and the lines are painted.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.howto.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
howto_is "$window_uuid" || exit 0
howto_refresh "$window_uuid"
exit 0
