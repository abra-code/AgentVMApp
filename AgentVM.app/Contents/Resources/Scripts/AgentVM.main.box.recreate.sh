#!/bin/sh
# AgentVM.main.box.recreate.sh
# Recreate in the box detail pane: the Recreate window opens for that box, or comes to the front,
# where the image the box is made from is chosen and Recreate is asked. Status is read again first:
# a box that started meanwhile, or that is temporary or held by a job, gets no window. The image
# is the window's to judge, so a box whose image was deleted gets one too.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.recreate.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
name="$(ui_get box "$window_uuid")"
[ -n "$name" ] || exit 0
main_read_status "$window_uuid"
read_status=$?
main_paint "$window_uuid"
# Not when status failed: the rows would be old ones (the note under the lists says why).
[ "$read_status" -eq 0 ] || exit 0
main_box_askable "$window_uuid" "$name" recreate || exit 0
recreate_ask "$name" "$OMC_CURRENT_COMMAND_GUID"
exit 0
