#!/bin/sh
# AgentVM.main.box.start.sh
# Start, in the box detail pane: starts the selected box as an agent-vm job, with no owner, so it
# runs until it is stopped, whether or not the app is running. Status is read first: a box that is
# no longer stopped, or that a job holds, is not started. The card and the pane then follow the
# job, and a start that fails is said when it ends.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
name="$(ui_get box "$window_uuid")"
[ -n "$name" ] || exit 0
main_read_status "$window_uuid"
read_status=$?
main_paint "$window_uuid"
[ "$read_status" -eq 0 ] || exit 0
main_box_askable "$window_uuid" "$name" start || exit 0
main_box_job "$window_uuid" "$name" start "$OMC_CURRENT_COMMAND_GUID"
exit 0
