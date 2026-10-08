#!/bin/sh
# AgentVM.logs.close.sh
# The Where the Logs Are window closed (END_CANCEL_SUBCOMMAND_ID): there is no such window any
# more, if this one was it, and the window's value and cache files go.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.logs.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
ui_item_release logs window "$window_uuid"
ui_set logs "$window_uuid" ""
ui_cache_clear "$window_uuid"
exit 0
