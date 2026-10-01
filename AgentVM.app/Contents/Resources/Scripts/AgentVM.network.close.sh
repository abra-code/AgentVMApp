#!/bin/sh
# AgentVM.network.close.sh
# A box's network window closed (END_CANCEL_SUBCOMMAND_ID): the box has no network window any
# more, if this one was it, and the window's box, its pending question and its cache files go,
# edits not applied among them.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.network.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
box="$(ui_get box "$window_uuid")"
[ -n "$box" ] && ui_item_release network "$box" "$window_uuid"
ui_set box "$window_uuid" ""
ui_set net_allow "$window_uuid" ""
ui_cache_clear "$window_uuid"
exit 0
