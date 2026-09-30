#!/bin/sh
# AgentVM.main.image.details.sh
# An image in a window of its own, from the main window: a double-click on a card of the image
# list (which names the card by its index), or the detail pane's Open in Window (the selection).
# Brings that image's window to the front, or opens one.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
name=""
if [ "${OMC_ACTIONUI_TRIGGER_VIEW_ID:-}" = "$MAIN_IMAGES_ID" ]; then
    name="$(main_shown_name "$window_uuid" images "${OMC_ACTIONUI_TRIGGER_CONTEXT:-}")"
else
    name="$(ui_get image "$window_uuid")"
fi
[ -n "$name" ] || exit 0
ui_item_open image "$name" "$OMC_CURRENT_COMMAND_GUID"
