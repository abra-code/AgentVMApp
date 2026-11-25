#!/bin/sh
# AgentVM.main.tab.sh
# A tab of the main window was chosen (its index is the context). Opening the Sessions tab reads
# the sessions, and measures what they hold when the kept measurement is stale
# (lib.agentvm.sessions.sh). The other tabs read nothing more: the poll loop keeps them current.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
index="$(printf '%s' "${OMC_ACTIONUI_TRIGGER_CONTEXT:-}" | /usr/bin/tr -cd '0123456789')"
[ "$index" = "$SES_TAB_INDEX" ] || exit 0
ses_open "$window_uuid"
exit 0
