#!/bin/sh
# AgentVM.main.image.rename.sh
# The Rename button beside the image's name in its pane: the Rename window opens for that image, or
# comes to the front. Not for an image a job holds or another command is changing; the lists are
# as the window last read them, and agent-vm has the last word.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.rename.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
name="$(ui_get image "$window_uuid")"
[ -n "$name" ] || exit 0
main_image_renamable "$window_uuid" "$name" || exit 0
rename_ask image "$name" "$OMC_CURRENT_COMMAND_GUID"
exit 0
