#!/bin/sh
# AgentVM.programs.close.sh
# A box's programs window closed (END_CANCEL_SUBCOMMAND_ID): the box has no programs window any
# more, if this one was it, and the window's box and its cache files go.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.programs.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
box="$(ui_get box "$window_uuid")"
[ -n "$box" ] && ui_item_release programs "$box" "$window_uuid"
ui_set box "$window_uuid" ""
ui_cache_clear "$window_uuid"
exit 0
