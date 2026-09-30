#!/bin/sh
# AgentVM.main.init.sh
# The main window opens (INIT_SUBCOMMAND_ID): reads agent-vm, doctor and status, paints the face
# that fits, and starts the poll loop that keeps it current.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
# A new window has no loop and no selections yet.
ui_set poll "$window_uuid" ""
ui_set box "$window_uuid" ""
ui_set image "$window_uuid" ""
main_refresh "$window_uuid" full
"$next_command" "$OMC_CURRENT_COMMAND_GUID" "AgentVM.main.poll"
