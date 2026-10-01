#!/bin/sh
# AgentVM.update.activated.sh
# An image's update window came to the front (WINDOW_DID_ACTIVATE_SUBCOMMAND_ID): status is read
# again, since the image may have been updated, taken by a job or deleted meanwhile. The ticks
# stay as they are.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.update.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
[ -n "$(update_image "$window_uuid")" ] || exit 0
update_refresh "$window_uuid"
exit 0
