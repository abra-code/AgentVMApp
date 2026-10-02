#!/bin/sh
# AgentVM.newimage.activated.sh
# The New Image window came to the front (WINDOW_DID_ACTIVATE_SUBCOMMAND_ID): agent-vm is read
# again, and what follows it is repainted. No field and no checkbox is touched.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.newimage.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
newimage_is "$window_uuid" || exit 0
newimage_refresh "$window_uuid"
exit 0
