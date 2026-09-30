#!/bin/sh
# AgentVM.image.delete.confirmed.sh
# Delete, in the question AgentVM.image.delete asked: agent-vm deletes the image, and its window
# closes. When agent-vm refuses (another agent-vm process uses the image: a build, an update, a
# box being made from it), its reason is shown and the window stays.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.image.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
name="$(ui_get item "$window_uuid")"
[ -n "$name" ] || exit 0
agentvm_image_delete "$name"
status=$?
if [ "$status" -ne 0 ]; then
    message="$(agentvm_last_error "$status")"
    "$dialog" "$window_uuid" omc_window omc_present_alert "Image $name was not deleted" "$message" "OK::"
    image_refresh "$window_uuid"
    exit 0
fi
ui_item_release image "$name" "$window_uuid"
"$dialog" "$window_uuid" omc_window omc_terminate_cancel
