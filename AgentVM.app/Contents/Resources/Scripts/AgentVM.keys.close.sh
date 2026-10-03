#!/bin/sh
# AgentVM.keys.close.sh
# The Agent Keys window closed (END_CANCEL_SUBCOMMAND_ID): there is no Agent Keys window any
# more, if this one was it, and the window's values and cache files go. What was typed into the
# field and not stored is gone with the window.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.keys.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
ui_item_release keys window "$window_uuid"
ui_set keys "$window_uuid" ""
ui_set key "$window_uuid" ""
ui_set keyagent "$window_uuid" ""
ui_set key_remove "$window_uuid" ""
ui_set busy "$window_uuid" ""
ui_cache_clear "$window_uuid"
exit 0
