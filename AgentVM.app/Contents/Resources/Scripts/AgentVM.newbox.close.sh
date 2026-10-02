#!/bin/sh
# AgentVM.newbox.close.sh
# The New Box window closed (END_CANCEL_SUBCOMMAND_ID): there is no New Box window any more, if
# this one was it, and the window's values and cache files go.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.newbox.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
ui_item_release newbox window "$window_uuid"
for key in $NBOX_KEYS; do
    ui_set "$key" "$window_uuid" ""
done
ui_cache_clear "$window_uuid"
exit 0
