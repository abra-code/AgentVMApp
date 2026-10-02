#!/bin/sh
# AgentVM.getmacos.close.sh
# The Get macOS window closed (END_CANCEL_SUBCOMMAND_ID): there is no Get macOS window any more,
# if this one was it, and the window's values and cache files go. A download it started goes on.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.getmacos.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
ui_item_release getmacos window "$window_uuid"
ui_set getmacos "$window_uuid" ""
ui_set busy "$window_uuid" ""
ui_cache_clear "$window_uuid"
exit 0
