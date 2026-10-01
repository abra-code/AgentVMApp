#!/bin/sh
# AgentVM.network.host.selected.sh
# A row of the Settings tab's other hosts was selected or deselected: Remove follows.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.network.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
selected=0
[ -n "$OMC_ACTIONUI_TABLE_604_COLUMN_1_VALUE" ] && selected=1
ui_enable "$window_uuid" "$NET_REMOVE_ID" "$selected"
