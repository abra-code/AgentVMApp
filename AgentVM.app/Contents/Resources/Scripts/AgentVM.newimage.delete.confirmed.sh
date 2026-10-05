#!/bin/sh
# AgentVM.newimage.delete.confirmed.sh
# Delete, in the question AgentVM.newimage.delete asked: agent-vm deletes the image asked about,
# agent-vm is read again, and the note follows: with the name free, it is empty and Delete...
# is gone, so Continue goes on. When agent-vm refuses (a command in Terminal is still building
# the image), its reason is shown and the note stays. The main window reads the lists again.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.newimage.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
newimage_is "$window_uuid" || exit 0
name="$(ui_get delete "$window_uuid")"
# Read once: a second confirmation, or one without a question, deletes nothing.
ui_set delete "$window_uuid" ""
[ -n "$name" ] && agentvm_valid_name "$name" || exit 0
agentvm_image_delete "$name"
status=$?
if [ "$status" -ne 0 ]; then
    "$dialog" "$window_uuid" omc_window omc_present_alert "Image $name was not deleted" \
        "$(agentvm_last_error "$status")" "OK::"
fi
newimage_read "$window_uuid"
read_status=$?
# The window closed while agent-vm was read: the cache folder the reading made again goes.
if newimage_is "$window_uuid"; then
    newimage_repaint_note "$window_uuid" "$read_status"
else
    ui_cache_clear "$window_uuid"
fi
main_window="$(ui_item_window main window)"
[ -n "$main_window" ] && main_refresh "$main_window" status
exit 0
