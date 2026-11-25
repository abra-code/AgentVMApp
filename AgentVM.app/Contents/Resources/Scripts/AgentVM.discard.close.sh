#!/bin/sh
# AgentVM.discard.close.sh
# The Discard Sessions window closed (END_CANCEL_SUBCOMMAND_ID): there is no such window any more,
# if this one was it, and the window's values and cache files go.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.discard.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
ui_item_release discard window "$window_uuid"
ui_set discard "$window_uuid" ""
ui_set discard-choice "$window_uuid" ""
ui_set discard-date "$window_uuid" ""
ui_set discard-ids "$window_uuid" ""
ui_set busy "$window_uuid" ""
ui_cache_clear "$window_uuid"
exit 0
