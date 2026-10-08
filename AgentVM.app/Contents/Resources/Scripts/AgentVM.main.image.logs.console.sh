#!/bin/sh
# AgentVM.main.image.logs.console.sh
# Show Console Log, on the Logs row of the image pane: the console of a Linux image's
# builds and updates (console.log in the image's folder), selected in a Finder window. Nothing
# when no image is selected or the image has no console log.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
name="$(ui_get image "$window_uuid")"
[ -n "$name" ] || exit 0
main_show_file "$(main_image_console_log "$(main_row "$window_uuid" images "$name" | /usr/bin/cut -f11)")"
exit 0
