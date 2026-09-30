#!/bin/sh
# AgentVM.main.image.details.sh
# Details of an image from the main window: the images table's "..." button or a double-click on
# a row (both name the row by its index), or the action row's Details... (the selection). Brings
# that image's window to the front, or opens one.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
name=""
if [ "${OMC_ACTIONUI_TRIGGER_VIEW_ID:-}" = "$MAIN_IMAGES_ID" ]; then
    name="$(main_shown_name "$window_uuid" images "${OMC_ACTIONUI_TRIGGER_CONTEXT:-}")"
else
    selected="$(ui_get selected "$window_uuid")"
    case "$selected" in
        image:*) name="${selected#image:}" ;;
    esac
fi
[ -n "$name" ] || exit 0
ui_item_open image "$name" "$OMC_CURRENT_COMMAND_GUID"
