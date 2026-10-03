#!/bin/sh
# AgentVM.howto.close.sh
# The How to Use a Box window closed (END_CANCEL_SUBCOMMAND_ID): there is no such window any
# more, if this one was it, and the window's value and cache files go.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.howto.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
ui_item_release howto window "$window_uuid"
ui_set howto "$window_uuid" ""
ui_cache_clear "$window_uuid"
exit 0
