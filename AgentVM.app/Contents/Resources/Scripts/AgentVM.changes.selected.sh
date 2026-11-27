#!/bin/sh
# AgentVM.changes.selected.sh
# A change selected in the Session Changes window: it is shown on the right. The row's hidden
# sixth column is its number in the window's rows.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.changes.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
chg_is "$window_uuid" || exit 0
row="$OMC_ACTIONUI_TABLE_5504_COLUMN_6_VALUE"
chg_select "$window_uuid" "$row"
exit 0
