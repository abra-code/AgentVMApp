#!/bin/sh
# AgentVM.image.delete.sh
# Delete...: asks first, saying what deleting frees and what it means for the boxes and images
# made from the image, read again now so the answer is about what exists. Delete in the question
# runs AgentVM.image.delete.confirmed.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.image.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
image_refresh "$window_uuid"
read_status=$?
# Only a question about what exists now: not when agent-vm cannot be used or status failed (the
# rows would be old ones). An image agent-vm could not measure is still asked about, without the
# space it frees.
[ "$read_status" -eq 0 ] || [ "$read_status" -eq 11 ] || exit 0
name="$(ui_get item "$window_uuid")"
[ -n "$name" ] || exit 0
row="$(image_status_row "$window_uuid" "$name")"
[ -n "$row" ] || exit 0
"$dialog" "$window_uuid" omc_window omc_present_alert "Delete image $name?" \
    "$(image_delete_question "$window_uuid")" \
    "Cancel:cancel:" "Delete:destructive:AgentVM.image.delete.confirmed"
