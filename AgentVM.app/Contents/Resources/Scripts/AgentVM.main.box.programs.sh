#!/bin/sh
# AgentVM.main.box.programs.sh
# Details..., on the box pane's Programs running row: brings the selected box's programs window to
# the front, or opens one.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
box="$(ui_get box "$window_uuid")"
[ -n "$box" ] || exit 0
ui_item_open programs "$box" "$OMC_CURRENT_COMMAND_GUID"
exit 0
