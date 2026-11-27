#!/bin/sh
# AgentVM.main.session.changes.sh
# Changes... under the Sessions tab's session table, or a double-click on a row (the row index is
# the context): that session's Session Changes window in front.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
[ -n "$(ui_get session-project "$window_uuid")" ] || exit 0
row="$(printf '%s' "${OMC_ACTIONUI_TRIGGER_CONTEXT:-}" | /usr/bin/tr -cd '0123456789')"
ses_changes "$window_uuid" "$row" "$OMC_CURRENT_COMMAND_GUID"
exit 0
