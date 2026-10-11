#!/bin/sh
# AgentVM.rename.close.sh
# The Rename window closed (END_CANCEL_SUBCOMMAND_ID): there is no such window any more, if this
# one was it, and the window's values go.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.rename.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
ui_item_release rename window "$window_uuid"
ui_set rename "$window_uuid" ""
ui_set busy "$window_uuid" ""
ui_cache_clear "$window_uuid"
exit 0
