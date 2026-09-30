#!/bin/sh
# AgentVM.image.activated.sh
# An image's window became active (WINDOW_DID_ACTIVATE_SUBCOMMAND_ID): reads and paints it again,
# since the image, or what was made from it, may have changed in the main window, in Terminal or
# in Cadabra meanwhile.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.image.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
image_refresh "$window_uuid"
exit 0
