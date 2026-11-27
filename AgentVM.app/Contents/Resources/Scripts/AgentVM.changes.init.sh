#!/bin/sh
# AgentVM.changes.init.sh
# A Session Changes window opened: it takes the session the main window asked for (a window opened
# without a request of this run of the app closes), becomes that session's window (or brings the
# one already open to the front and closes), and compares the project with the session's snapshot.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.changes.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
ui_set changes "$window_uuid" ""
session="$(ui_item_request changes)"
if [ -z "$session" ] || ! agentvm_valid_session_id "$session"; then
    "$dialog" "$window_uuid" omc_window omc_terminate_cancel
    exit 0
fi
existing="$(ui_item_window changes "$session")"
if [ -n "$existing" ] && [ "$existing" != "$window_uuid" ]; then
    "$dialog" "$existing" omc_window omc_select
    "$dialog" "$window_uuid" omc_window omc_terminate_cancel
    exit 0
fi
ui_set changes "$window_uuid" "$session"
ui_item_claim changes "$session" "$window_uuid"
"$dialog" "$window_uuid" omc_window "Session Changes"
chg_paint "$window_uuid"
chg_refresh "$window_uuid"
# Painting reads the cache, which makes its folder again for a window that closed meanwhile.
chg_is "$window_uuid" || ui_cache_clear "$window_uuid"
exit 0
