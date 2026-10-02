#!/bin/sh
# AgentVM.access.activated.sh
# An image's Full Disk Access guide came to the front (WINDOW_DID_ACTIVATE_SUBCOMMAND_ID): status
# is read again, since the grant may have been made, or the image taken by a job or deleted,
# meanwhile; and the poll loop starts if a setup job holds the image and no loop follows it.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.access.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
[ -n "$(access_image "$window_uuid")" ] || exit 0
access_refresh "$window_uuid"
access_moving "$window_uuid" || exit 0
access_poll_running "$window_uuid" && exit 0
"$next_command" "$OMC_CURRENT_COMMAND_GUID" "AgentVM.access.poll"
exit 0
