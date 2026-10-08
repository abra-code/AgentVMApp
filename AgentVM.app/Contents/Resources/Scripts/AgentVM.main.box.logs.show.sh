#!/bin/sh
# AgentVM.main.box.logs.show.sh
# Show in Finder, on the Logs row of the box pane: the selected box's log files are in its
# folder in the store, and the first one that is there is selected in a Finder window. Nothing
# when no box is selected or the box has logged nothing yet.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
name="$(ui_get box "$window_uuid")"
[ -n "$name" ] || exit 0
main_show_file "$(main_box_log_file "$(main_box_folder "$window_uuid" "$name")")"
exit 0
