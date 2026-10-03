#!/bin/sh
# AgentVM.keys.activated.sh
# The Agent Keys window came to the front (WINDOW_DID_ACTIVATE_SUBCOMMAND_ID): the agents and
# their keys are read again (one may have been stored in Terminal meanwhile), and the window is
# painted.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.keys.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
keys_is "$window_uuid" || exit 0
keys_refresh "$window_uuid"
exit 0
