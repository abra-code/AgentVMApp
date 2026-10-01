#!/bin/sh
# AgentVM.main.image.delete.sh
# Delete... in the image detail pane: asks first, saying what deleting frees and what it means for
# the boxes and images made from the image, read again now so the answer is about what exists.
# The image asked about is kept as the window's pending delete: the confirmation's handler deletes
# that one, whatever the selection is by then. Delete in the question runs
# AgentVM.main.image.delete.confirmed.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
name="$(ui_get image "$window_uuid")"
[ -n "$name" ] || exit 0
ui_set image_delete "$window_uuid" ""
main_read_status "$window_uuid"
read_status=$?
# Only a question about what exists now: not when status failed (the rows would be old ones; the
# note under the lists says why). An image agent-vm could not measure is still asked about,
# without the space it frees.
if [ "$read_status" -ne 0 ]; then
    main_paint "$window_uuid"
    exit 0
fi
if [ -n "$(main_row "$window_uuid" images "$name")" ]; then
    main_read_info "$window_uuid" image "$name"
fi
main_paint "$window_uuid"
[ -n "$(main_row "$window_uuid" images "$name")" ] || exit 0
ui_set image_delete "$window_uuid" "$name"
"$dialog" "$window_uuid" omc_window omc_present_alert "Delete image $name?" \
    "$(main_image_delete_question "$window_uuid" "$name")" \
    "Cancel:cancel:" "Delete:destructive:AgentVM.main.image.delete.confirmed"
