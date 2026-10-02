#!/bin/sh
# AgentVM.access.close.sh
# An image's Full Disk Access guide closed (END_CANCEL_SUBCOMMAND_ID): the poll loop ends at its
# next wake, the image has no guide any more, if this one was it, and the window's values and
# cache files go. A setup it started goes on: the image's own window is what ends it.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.access.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
ui_set poll "$window_uuid" "closed"
image="$(access_image "$window_uuid")"
[ -n "$image" ] && ui_item_release access "$image" "$window_uuid"
ui_set image "$window_uuid" ""
ui_set job "$window_uuid" ""
ui_cache_clear "$window_uuid"
exit 0
