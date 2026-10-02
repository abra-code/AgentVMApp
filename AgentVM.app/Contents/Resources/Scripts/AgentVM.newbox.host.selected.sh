#!/bin/sh
# AgentVM.newbox.host.selected.sh
# A row of the network step's other hosts was selected or deselected: Remove follows.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.newbox.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
newbox_is "$window_uuid" || exit 0
[ "$(newbox_step "$window_uuid")" = "2" ] || exit 0
selected=0
[ -n "${OMC_ACTIONUI_TABLE_2066_COLUMN_1_VALUE:-}" ] && selected=1
ui_enable "$window_uuid" "$NBOX_REMOVE_ID" "$selected"
exit 0
