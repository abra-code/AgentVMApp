#!/bin/sh
# AgentVM.main.image.rebuild.sh
# Build Again..., in the image detail pane, shown for an image whose base changed since it was
# made from it: asks first, saying why, what a rebuild does, and what it means for the image's
# boxes and the images built from it, read again now so the answer is about what exists. The
# image asked about is kept as the window's pending rebuild: the confirmation's handler builds
# that one again, whatever the selection is by then. Build Again in the question runs
# AgentVM.main.image.rebuild.confirmed.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
name="$(ui_get image "$window_uuid")"
[ -n "$name" ] || exit 0
ui_set image_rebuild "$window_uuid" ""
main_read_status "$window_uuid"
read_status=$?
main_paint "$window_uuid"
# Only a question about what exists now: not when status failed (the rows would be old ones; the
# note under the lists says why), nor about an image that no longer needs it, is not ready, or that
# a job or another command holds: the pane now says which.
[ "$read_status" -eq 0 ] || exit 0
main_image_rebuildable "$window_uuid" "$name" || exit 0
ui_set image_rebuild "$window_uuid" "$name"
"$dialog" "$window_uuid" omc_window omc_present_alert "Build image $name again?" \
    "$(main_image_rebuild_question "$window_uuid" "$name")" \
    "Cancel:cancel:" "Build Again::AgentVM.main.image.rebuild.confirmed"
exit 0
