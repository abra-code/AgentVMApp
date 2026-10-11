#!/bin/sh
# AgentVM.main.box.rename.sh
# The Rename button beside the box's name in its pane: the Rename window opens for that box, or comes
# to the front. For a stopped box that is kept and that no job holds, as agent-vm renames
# no other; the lists are as the window last read them, and agent-vm has the last word.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.rename.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
name="$(ui_get box "$window_uuid")"
[ -n "$name" ] || exit 0
main_box_renamable "$window_uuid" "$name" || exit 0
rename_ask box "$name" "$OMC_CURRENT_COMMAND_GUID"
exit 0
