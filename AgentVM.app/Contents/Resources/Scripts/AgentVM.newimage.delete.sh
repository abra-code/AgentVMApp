#!/bin/sh
# AgentVM.newimage.delete.sh
# Delete..., beside the note that says the new image's name belongs to an image that appears not
# ready: asks first, saying what agent-vm reports about that image, where it is and what deleting
# frees, read again now so the answer is about what exists. The image asked about is
# kept as the window's pending delete: the confirmation's handler deletes that one. Delete in
# the question runs AgentVM.newimage.delete.confirmed. No field is read or touched.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.newimage.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
newimage_is "$window_uuid" || exit 0
newimage_enter "$window_uuid" || exit 0
name="$(ui_get taken "$window_uuid")"
ui_set delete "$window_uuid" ""
agentvm_valid_name "$name" || exit 0
newimage_read "$window_uuid"
read_status=$?
# The window closed while agent-vm was read: the cache folder the reading made again goes.
if ! newimage_is "$window_uuid"; then
    ui_cache_clear "$window_uuid"
    exit 0
fi
# Not when agent-vm could not be read (the rows would be old ones, and the image may be ready by
# now): the note says why instead, and the offer goes with the note it stood beside.
if [ "$read_status" -ne 0 ]; then
    newimage_repaint_note "$window_uuid" "$read_status"
    exit 0
fi
# Only a question about what exists now: an image that is gone, became ready, or is being built
# after all is not asked about, and the note follows what was read.
if ! newimage_deletable "$window_uuid" "$name"; then
    newimage_repaint_note "$window_uuid"
    exit 0
fi
main_read_info "$window_uuid" image "$name"
ui_set delete "$window_uuid" "$name"
"$dialog" "$window_uuid" omc_window omc_present_alert "Delete image $name?" \
    "$(main_unready_image_question "$window_uuid" "$name")" \
    "Cancel:cancel:" "Delete:destructive:AgentVM.newimage.delete.confirmed"
exit 0
