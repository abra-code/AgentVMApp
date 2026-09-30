#!/bin/sh
# AgentVM.image.close.sh
# An image's window closed (END_CANCEL_SUBCOMMAND_ID): the image has no window any more, if this
# one was it, and the window's name and cache files go.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.image.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
name="$(ui_get item "$window_uuid")"
[ -n "$name" ] && ui_item_release image "$name" "$window_uuid"
ui_set item "$window_uuid" ""
ui_cache_clear "$window_uuid"
