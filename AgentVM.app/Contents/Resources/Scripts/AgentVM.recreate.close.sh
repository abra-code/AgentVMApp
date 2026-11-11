#!/bin/sh
# AgentVM.recreate.close.sh
# The Recreate window closed (END_CANCEL_SUBCOMMAND_ID): there is no such window any more, if this
# one was it, and the window's values and cache files go.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.recreate.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
ui_item_release recreate window "$window_uuid"
ui_set recreate "$window_uuid" ""
ui_set picked "$window_uuid" ""
ui_set busy "$window_uuid" ""
ui_cache_clear "$window_uuid"
exit 0
