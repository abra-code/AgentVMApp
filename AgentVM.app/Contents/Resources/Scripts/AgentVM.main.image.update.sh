#!/bin/sh
# AgentVM.main.image.update.sh
# Update..., in the image pane: brings the selected image's update window to the front, or opens
# one. The window says what can be updated and asks; nothing is started here.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
name="$(ui_get image "$window_uuid")"
[ -n "$name" ] || exit 0
[ -n "$(main_row "$window_uuid" images "$name")" ] || exit 0
ui_item_open update "$name" "$OMC_CURRENT_COMMAND_GUID"
exit 0
