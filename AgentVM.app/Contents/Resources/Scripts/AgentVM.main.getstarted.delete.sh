#!/bin/sh
# AgentVM.main.getstarted.delete.sh
# Delete..., under New Image... in Get started, shown while the only images are ones whose
# build failed: asks about the first of them, saying why its build failed, where it is and what
# deleting frees, read again now so the answer is about what exists. The image asked about is
# kept as the window's pending delete, and Delete in the question runs
# AgentVM.main.image.delete.confirmed, as Delete... under the image list does.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
ui_set image_delete "$window_uuid" ""
main_read_status "$window_uuid"
read_status=$?
main_paint "$window_uuid"
# Only a question about what exists now: not when status failed (the rows would be old ones).
[ "$read_status" -eq 0 ] || exit 0
name="$(main_rows "$window_uuid" images | /usr/bin/awk -F'\t' '$2 == "failed" { print $1; exit }')"
agentvm_valid_name "$name" || exit 0
# Nor about an image a job holds, or another agent-vm command is changing.
[ -z "$(main_job "$window_uuid" image "$name")" ] || exit 0
main_image_busy "$window_uuid" "$name" && exit 0
main_read_info "$window_uuid" image "$name"
ui_set image_delete "$window_uuid" "$name"
"$dialog" "$window_uuid" omc_window omc_present_alert "Delete image $name?" \
    "$(main_unready_image_question "$window_uuid" "$name")" \
    "Cancel:cancel:" "Delete:destructive:AgentVM.main.image.delete.confirmed"
exit 0
