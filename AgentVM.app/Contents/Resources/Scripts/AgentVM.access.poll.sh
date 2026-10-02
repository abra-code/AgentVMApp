#!/bin/sh
# AgentVM.access.poll.sh
# A Full Disk Access guide's poll loop (lib.agentvm.access.sh, access_poll), chained by the init,
# activate and open handlers. Runs until no setup job holds the image, the window closes, a newer
# loop takes over, or the app quits.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.access.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
[ -n "$(access_image "$window_uuid")" ] || exit 0
access_poll "$window_uuid"
exit 0
