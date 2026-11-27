#!/bin/sh
# AgentVM.changes.tick.sh
# An entry's checkbox in the Session Changes window changed (the row index is the context): the
# tick is kept, with the count and Undo Ticked... following. Nothing is undone until then.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.changes.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
chg_is "$window_uuid" || exit 0
row="$(printf '%s' "${OMC_ACTIONUI_TRIGGER_CONTEXT:-}" | /usr/bin/tr -cd '0123456789')"
chg_tick "$window_uuid" "$row"
exit 0
