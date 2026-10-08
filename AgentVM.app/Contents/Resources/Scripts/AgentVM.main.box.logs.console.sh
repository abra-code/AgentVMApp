#!/bin/sh
# AgentVM.main.box.logs.console.sh
# Open in Console, on the Logs row of the box pane: the selected box's own log (supervisor.log:
# its start and stop, the folders shared with it) opens in Console, which searches and follows
# it. Nothing when no box is selected or the box has no such log yet.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
name="$(ui_get box "$window_uuid")"
[ -n "$name" ] || exit 0
main_open_in_console "$(main_box_own_log "$(main_box_folder "$window_uuid" "$name")")"
exit 0
