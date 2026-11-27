#!/bin/sh
# AgentVM.changes.close.sh
# A Session Changes window closed: it is no longer its session's window, and its values and cache
# go.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.changes.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
session="$(chg_session "$window_uuid")"
[ -n "$session" ] && ui_item_release changes "$session" "$window_uuid"
ui_set changes "$window_uuid" ""
ui_set changes-selected "$window_uuid" ""
ui_set changes-selected-path "$window_uuid" ""
ui_set busy "$window_uuid" ""
ui_cache_clear "$window_uuid"
exit 0
