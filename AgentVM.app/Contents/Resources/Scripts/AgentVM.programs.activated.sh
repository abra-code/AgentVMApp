#!/bin/sh
# AgentVM.programs.activated.sh
# A box's programs window became active (WINDOW_DID_ACTIVATE_SUBCOMMAND_ID): reads and paints it
# again, since programs may have started or ended in the box meanwhile.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.programs.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
prog_refresh "$window_uuid"
exit 0
