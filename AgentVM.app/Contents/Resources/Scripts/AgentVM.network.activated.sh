#!/bin/sh
# AgentVM.network.activated.sh
# A box's network window became active (WINDOW_DID_ACTIVATE_SUBCOMMAND_ID): reads and paints it
# again, since the box may have been started or stopped, and its rules changed, in the main
# window, in Terminal or in Cadabra meanwhile. Edits not applied yet stay.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.network.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
net_refresh "$window_uuid"
exit 0
