#!/bin/sh
# AgentVM.exclusions.tick.sh
# A folder's checkbox in the Exclusions window changed (the row index is the context): the tick
# is kept, and the lines under the table follow. Nothing is saved until Save.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.exclusions.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
excl_is "$window_uuid" || exit 0
row="$(printf '%s' "${OMC_ACTIONUI_TRIGGER_CONTEXT:-}" | /usr/bin/tr -cd '0123456789')"
excl_tick "$window_uuid" "$row"
exit 0
