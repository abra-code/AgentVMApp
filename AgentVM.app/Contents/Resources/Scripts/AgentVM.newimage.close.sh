#!/bin/sh
# AgentVM.newimage.close.sh
# The New Image window closed (END_CANCEL_SUBCOMMAND_ID): there is no New Image window any more,
# if this one was it, and the window's values and cache files go. A build it started goes on.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.newimage.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
ui_item_release newimage window "$window_uuid"
for key in newimage step start ticks name cpus memory disk auto_name auto_disk busy; do
    ui_set "$key" "$window_uuid" ""
done
ui_cache_clear "$window_uuid"
exit 0
