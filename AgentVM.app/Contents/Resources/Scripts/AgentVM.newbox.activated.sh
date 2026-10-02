#!/bin/sh
# AgentVM.newbox.activated.sh
# The New Box window came to the front (WINDOW_DID_ACTIVATE_SUBCOMMAND_ID): agent-vm is read
# again, and what follows it is repainted. No field is touched.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.newbox.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
newbox_is "$window_uuid" || exit 0
newbox_refresh "$window_uuid"
exit 0
