#!/bin/sh
# AgentVM.image.show.sh
# Show in Finder: the image's folder in the store, selected in a Finder window.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.image.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
name="$(ui_get item "$window_uuid")"
[ -n "$name" ] || exit 0
folder="$(image_status_row "$window_uuid" "$name" | /usr/bin/cut -f11)"
[ -n "$folder" ] && [ -d "$folder" ] || exit 0
"$open_tool" -R "$folder"
