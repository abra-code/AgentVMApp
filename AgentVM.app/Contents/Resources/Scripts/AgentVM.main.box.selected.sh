#!/bin/sh
# AgentVM.main.box.selected.sh
# A card of the box list was selected or deselected: the box list's selection becomes that box,
# or nothing, and the detail pane follows.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
name="$OMC_ACTIONUI_TABLE_311_COLUMN_1_VALUE"
if [ -n "$name" ] && agentvm_valid_name "$name"; then
    ui_set box "$window_uuid" "$name"
else
    ui_set box "$window_uuid" ""
fi
main_paint_box_detail "$window_uuid"
