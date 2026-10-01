#!/bin/sh
# AgentVM.main.close.sh
# The main window closed (END_CANCEL_SUBCOMMAND_ID): the poll loop ends at its next wake, a URL no
# longer finds this window, and the window's selections, its pending questions and its cache files
# go.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
ui_set poll "$window_uuid" "closed"
ui_item_release main window "$window_uuid"
ui_set box "$window_uuid" ""
ui_set image "$window_uuid" ""
ui_set image_delete "$window_uuid" ""
ui_set box_delete "$window_uuid" ""
ui_set box_recreate "$window_uuid" ""
ui_cache_clear "$window_uuid"
