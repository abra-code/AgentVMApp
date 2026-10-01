#!/bin/sh
# AgentVM.update.close.sh
# An image's update window closed (END_CANCEL_SUBCOMMAND_ID): the image has no update window any
# more, if this one was it, and the window's values and cache files go. A job it started goes on.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.update.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
image="$(update_image "$window_uuid")"
[ -n "$image" ] && ui_item_release update "$image" "$window_uuid"
ui_set image "$window_uuid" ""
ui_set choices "$window_uuid" ""
ui_cache_clear "$window_uuid"
exit 0
