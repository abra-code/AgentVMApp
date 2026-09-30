#!/bin/sh
# AgentVM.main.image.delete.confirmed.sh
# Delete, in the question AgentVM.main.image.delete asked: agent-vm deletes the image asked about,
# and the lists are read again. When agent-vm refuses (another agent-vm process uses the image: a
# build, an update, a box being made from it), its reason is shown and the image stays selected.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
name="$(ui_get delete "$window_uuid")"
# Read once: a second confirmation, or one without a question, deletes nothing.
ui_set delete "$window_uuid" ""
[ -n "$name" ] && agentvm_valid_name "$name" || exit 0
agentvm_image_delete "$name"
status=$?
if [ "$status" -ne 0 ]; then
    message="$(agentvm_last_error "$status")"
    "$dialog" "$window_uuid" omc_window omc_present_alert "Image $name was not deleted" "$message" "OK::"
    main_refresh "$window_uuid" status
    exit 0
fi
selected="$(ui_get image "$window_uuid")"
[ "$selected" = "$name" ] && ui_set image "$window_uuid" ""
main_refresh "$window_uuid" status
