#!/bin/sh
# AgentVM.main.image.view.sh
# View, in the image detail pane: starts `image view` for the selected image as an agent-vm job,
# which boots the image and shows its screen in a window of agent-vm's, for setup done by hand.
# Status is read first: an image that is no longer ready, or that a job or another command holds,
# is not opened. The card and the pane then follow the job, which ends when that window is closed.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"
# For the one-click-at-a-time mark (wizard_enter).
. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.wizard.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
name="$(ui_get image "$window_uuid")"
[ -n "$name" ] || exit 0
# One click at a time: a second View clicked while agent-vm is read would start a second job,
# which agent-vm fails (the image is in use), and the window would say the image was not opened.
wizard_enter "$window_uuid" || exit 0
main_read_status "$window_uuid"
read_status=$?
main_paint "$window_uuid"
[ "$read_status" -eq 0 ] || exit 0
main_image_viewable "$window_uuid" "$name" || exit 0
# Off from here: a second click while the job starts must not start a second one.
ui_enable "$window_uuid" "$MAIN_IMAGE_VIEW_ID" 0
main_image_view "$window_uuid" "$name" "$OMC_CURRENT_COMMAND_GUID"
exit 0
