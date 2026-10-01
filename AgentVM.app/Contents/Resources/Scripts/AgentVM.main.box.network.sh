#!/bin/sh
# AgentVM.main.box.network.sh
# Details..., on the box pane's Network row: brings the selected box's network window to the
# front, or opens one.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
box="$(ui_get box "$window_uuid")"
[ -n "$box" ] || exit 0
ui_item_open network "$box" "$OMC_CURRENT_COMMAND_GUID"
exit 0
