#!/bin/sh
# AgentVM.main.image.access.sh
# Set Up..., on the image pane's Full Disk Access row: brings the selected image's Full Disk
# Access guide to the front, or opens one. The guide says what to do and asks; nothing is started
# here. A Linux image has no Full Disk Access to grant: the button is not shown for one, and no
# guide is opened for one however this handler came to run.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
name="$(ui_get image "$window_uuid")"
[ -n "$name" ] || exit 0
row="$(main_row "$window_uuid" images "$name")"
[ -n "$row" ] || exit 0
[ "$(printf '%s\n' "$row" | /usr/bin/cut -f12)" != "linux" ] || exit 0
ui_item_open access "$name" "$OMC_CURRENT_COMMAND_GUID"
exit 0
