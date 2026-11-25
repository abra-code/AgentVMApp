#!/bin/sh
# AgentVM.exclusions.close.sh
# The Exclusions window closed (END_CANCEL_SUBCOMMAND_ID): there is no such window any more, if
# this one was it, and the window's values and cache files go. What was ticked and not saved is
# forgotten.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.exclusions.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
ui_item_release exclusions window "$window_uuid"
ui_set exclusions "$window_uuid" ""
ui_set busy "$window_uuid" ""
ui_cache_clear "$window_uuid"
exit 0
