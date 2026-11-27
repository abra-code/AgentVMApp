#!/bin/sh
# AgentVM.main.session.selected.sh
# A session selected in the Sessions tab's session table (or none): Changes... follows. The row's
# hidden eighth column is the session's id.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
[ -n "$(ui_get session-project "$window_uuid")" ] || exit 0
ses_select_session "$window_uuid" "${OMC_ACTIONUI_TABLE_730_COLUMN_8_VALUE:-}"
exit 0
